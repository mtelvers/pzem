type t = {
  i2c : I2c.t;
  width : int;
  height : int;
}

let data = Stdint.Uint8.of_int 0x40
let command = Stdint.Uint8.of_int 0x00

let get_ok = function
  | Result.Ok x -> x
  | _ -> failwith "oops"

let init ~height ~width =
  let i2c =
    let fd = Unix.(openfile "/dev/i2c-1" [ O_RDWR ] 0) in
    get_ok (I2c.set_address fd 0x3c)
  in
  (* configure bank A and B as output *)
  let () =
    get_ok
      (I2c.write_i2c_block_data i2c command
         (List.map Stdint.Uint8.of_int
            [
              0x80;
              (* display off *)
              0xae;
              (* set display clock divide ratio and frequency *)
              0xD5;
              0x80;
              (* set size of multiplexer based on display height (31 for 32 rows) *)
              0xA8;
              31;
              (* set display vertical shift *)
              0xD3;
              0;
              (* set RAM display start line by ORing 6 LSBs *)
              0x40 lor 0x0;
              (* enable / disable charge pump *)
              0x8D;
              (* on *)
              0x14;
              (* set addressing mode (horizontal, vertical, or page) *)
              0x20;
              (* horizontal mode *)
              0;
              (* set column address 127 to display column 127 *)
              0xA1;
              (* set COM 0 to display row 0 *)
              0xC8;
              (* set COM pin hardware configuration *)
              0xDA;
              2;
              (* double-byte command to set contrast (1-256); *)
              0x81;
              0;
              (* set pre-charge period *)
              0xD9;
              (*   phase1 = 15, phase2 = 1 *)
              0xf1;
              (* set V_COMH voltage level *)
              0xDB;
              0x40;
              (* use RAM contents for display *)
              0xA4;
              (* normal display (not inverted) *)
              0xA6;
              (* stop scrolling *)
              0x2E;
              (* display ON (normal mode) *)
              0xAF;
            ]))
  in
  { i2c; width; height }

let clear { i2c; width; height } =
  let () = get_ok (I2c.write_i2c_block_data i2c command (List.map Stdint.Uint8.of_int [ 0x21; 0x0; width - 1; 0x22; 0x0; (height / 8) - 1 ])) in
  for _ = 0 to width * height / 8 do
    get_ok (I2c.write_byte_data i2c data (Stdint.Uint8.of_int 0))
  done

let ppm { i2c; _ } =
  let () = get_ok (I2c.write_i2c_block_data i2c command (List.map Stdint.Uint8.of_int [ 0x21; 0x0; Logo.width - 1; 0x22; 0x0; (Logo.height / 8) - 1 ])) in
  for page = 0 to 3 do
    for x = 0 to Logo.width - 1 do
      let b =
        List.fold_left
          (fun acc bit ->
            let bit_offset = x + (bit * 15 * 8) + (page * 15 * 8 * 8) in
            let byte_offset = bit_offset / 8 in
            let bit_position = bit_offset mod 8 in
            let b = (Array.get Logo.data byte_offset lsr (7 - bit_position)) land 1 lxor 1 in
            acc lor (b lsl bit))
          0 [ 0; 1; 2; 3; 4; 5; 6; 7 ]
      in
      get_ok (I2c.write_byte_data i2c data (Stdint.Uint8.of_int b))
    done
  done

let print { i2c; width; height } x y str =
  let () = get_ok (I2c.write_i2c_block_data i2c command (List.map Stdint.Uint8.of_int [ 0x21; x; width - 1; 0x22; y / 8; (height - 1 - y) / 8 ])) in
  String.iter
    (fun ch ->
      let x = Char.code ch in
      let ch = Font.font.(x) |> Array.to_list |> List.map Stdint.Uint8.of_int in
      let () = get_ok (I2c.write_i2c_block_data i2c data ch) in
      get_ok (I2c.write_byte_data i2c data (Stdint.Uint8.of_int 0)))
    str

let scroll { i2c; width; _ } = get_ok (I2c.write_i2c_block_data i2c command (List.map Stdint.Uint8.of_int [ 0xA3; 0x0; width - 1; 0x2f ]))

let scroll_right { i2c; _ } start_page end_page =
  get_ok (I2c.write_i2c_block_data i2c command (List.map Stdint.Uint8.of_int [ 0x26; 0x0; start_page; 1; end_page; 0x00; 0xff; 0x2f ]))

let scroll_left { i2c; _ } start_page end_page =
  get_ok (I2c.write_i2c_block_data i2c command (List.map Stdint.Uint8.of_int [ 0x27; 0x0; start_page; 7; end_page; 0x00; 0xff; 0x2f ]))

let scroll_stop { i2c; _ } = get_ok (I2c.write_i2c_block_data i2c command (List.map Stdint.Uint8.of_int [ 0x2e ]))
