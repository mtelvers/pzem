let () =
  let pzem = Pzem.init "/dev/serial0" in
  let ssd1306 = Ssd1306.init ~height:32 ~width:128 in
  let () = Ssd1306.clear ssd1306 in
  let () = Ssd1306.ppm ssd1306 in
  let () = Ssd1306.scroll_left ssd1306 0 3 in
  let () = Unix.sleepf 2. in
  let () = Ssd1306.scroll_stop ssd1306 in
  let () = Ssd1306.clear ssd1306 in
  let rec loop l =
    let tm = Unix.time () |> Unix.gmtime in
    if l = tm.tm_sec then
      let () = Unix.sleepf 0.1 in
      loop l
    else
      let date = Printf.sprintf "%i-%02i-%02i" (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday in
      let time = Printf.sprintf "%02i:%02i:%02i" tm.tm_hour tm.tm_min tm.tm_sec in
      Printf.printf "%s,%s," date time;
      ignore (Pzem.read_cmd pzem 0 10);
      let reply = Pzem.read_reply pzem in
      List.iteri
        (fun i (r, sym, sf) ->
          let display = match sf with
          | 0 -> Printf.sprintf "%.0f" (Array.get reply r)
          | 1 -> Printf.sprintf "%.1f" (Array.get reply r)
          | 2 -> Printf.sprintf "%.2f" (Array.get reply r)
          | 3 -> Printf.sprintf "%.3f" (Array.get reply r)
          | _ -> assert false in
          print_string (display ^ ",");
          Ssd1306.print ssd1306 (i / 4 * 64) (i mod 4 * 8) (display ^ " " ^ sym))
        [ (0, "V", 1); (1, "A", 3); (2, "W", 1); (3, "Wh", 0); (4, "Hz", 1); (5, "pf", 2) ];
      print_endline "";
      Ssd1306.print ssd1306 64 16 date;
      Ssd1306.print ssd1306 64 24 time;
      loop tm.tm_sec
  in loop 0
