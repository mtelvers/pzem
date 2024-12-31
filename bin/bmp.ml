type bmp = {
  width : int;
  height : int;
  bits_per_pixel : int;
  row_size : int;
  data : bytes;
}

let read file =
  In_channel.with_open_bin file @@ fun ic ->
  (* header (14) + dib (40) *)
  let buf = Bytes.create 54 in
  let _ = In_channel.input ic buf 0 54 in
  match Bytes.get_int16_be buf 0 with
  (* BM *)
  | 0x424d ->
      let width = Bytes.get_int32_le buf 18 |> Int32.to_int in
      let height = Bytes.get_int32_le buf 22 |> Int32.to_int in
      let bits_per_pixel = Bytes.get_uint16_le buf 28 in
      let row_size = ((bits_per_pixel * width) + 31) / 32 * 4 in
      let data = Bytes.create (height * width * row_size / 8) in
      let _ = In_channel.input ic data 0 (Bytes.length data) in
      { width; height; bits_per_pixel; row_size; data }
  | _ -> failwith "not bmp"
