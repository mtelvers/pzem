type t = { fd : Unix.file_descr }

let init dev =
  let flags = Unix.[ O_RDWR; O_NOCTTY ] in
  let fd = Unix.openfile dev flags 0o000 in
  let attrs = Unix.tcgetattr fd in
  let attrs' =
    {
      attrs with
      Unix.c_obaud = 9600; (* Baud rate *)
      c_ibaud = 9600;
      c_csize = 8; (* 8N1 *)
      c_parenb = false;
      c_cstopb = 1;
      c_cread = true; (* No flow control. *)
      c_clocal = true;
      c_ixon = false;
      c_ixoff = false;
      c_icanon = false; (* Raw input *)
      c_echo = false;
      c_echoe = false;
      c_isig = false;
      c_icrnl = false;
      c_opost = false; (* Raw output *)
    }
  in
  let () = Unix.tcsetattr fd Unix.TCSANOW attrs' in
  { fd }

let modrtu_crc =
  Bytes.fold_left
    (fun crc b ->
      let rec loop c = function
        | 0 -> c
        | n ->
            let lsb = c land 0x0001 in
            let c = c lsr 1 in
            let c = if lsb = 1 then c lxor 0xA001 else c in
            loop c (n - 1)
      in
      loop (crc lxor Char.code b) 8)
    0xffff

let read_cmd { fd } register num =
  let msg = Bytes.make 6 (Char.chr 0) in
  let () = Bytes.set_uint8 msg 0 1 in (* station id = 1 *)
  let () = Bytes.set_uint8 msg 1 4 in (* msg length *)
  let () = Bytes.set_uint16_be msg 2 register in (* start reg *)
  let () = Bytes.set_uint16_be msg 4 num in (* number of registers *)
  let crc = modrtu_crc msg in
  let msg_with_crc = Bytes.extend msg 0 2 in
  let () = Bytes.set_uint16_le msg_with_crc (Bytes.length msg) crc in
  Unix.write fd msg_with_crc 0 (Bytes.length msg_with_crc)

let read_byte { fd } =
  let buf = Bytes.make 1 '0' in
  if Unix.read fd buf 0 1 = 1 then Bytes.get_uint8 buf 0 else 0

let read_word { fd } =
  let buf = Bytes.make 2 '0' in
  if Unix.read fd buf 0 2 = 2 then Bytes.get_uint16_be buf 0 else 0

let read_reply { fd } =
  let buf = Bytes.make 1 '0' in
  let _ = Unix.read fd buf 0 1 in (* station id  *)
  let _ = Unix.read fd buf 0 1 in (* cmd id 04 = read *)
  let _ = Unix.read fd buf 0 1 in (* length in bytes *)
  let length = 2 + Bytes.get_uint8 buf 0 in (* CRC isn't part of the length *)
  let buf = Bytes.make length '0' in
  let rec read_all pos =
    match Unix.read fd buf pos (length - pos) with
    | 0 -> ()
    | n -> read_all (pos + n) in
  let () = read_all 0 in
  [|
    float_of_int (Bytes.get_uint16_be buf 0) /. 10.;
    float_of_int (Bytes.get_uint16_be buf 2 lor (Bytes.get_uint16_be buf 4 lsl 16)) /. 1000.;
    float_of_int (Bytes.get_uint16_be buf 6 lor (Bytes.get_uint16_be buf 8 lsl 16)) /. 1000.;
    float_of_int (Bytes.get_uint16_be buf 10 lor (Bytes.get_uint16_be buf 12 lsl 16));
    float_of_int (Bytes.get_uint16_be buf 14) /. 10.;
    float_of_int (Bytes.get_uint16_be buf 16) /. 100.;
  |]
