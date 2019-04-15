type color = 
  | Black
  | Red

type piece = 
  | P of (color * (int * int)) 
  | K of (color * (int * int)) 

type t = {
  pieces: piece list;
  turn: int; 
}

(** The type representing the result of an attempted move. *)
type result = Legal of t | Illegal


let new_game () = 
  {
    pieces = [
      P (Black,(1,1));P (Black,(3,1));P (Black,(5,1));P (Black,(7,1));P (Black,(2,2));
      P (Black,(4,2));P (Black,(6,2));P (Black,(8,2));P (Black,(1,3));P (Black,(3,3));
      P (Black,(5,3));P (Black,(7,3));P (Red,(2,8));P (Red,(4,8));P (Red,(6,8));
      P (Red,(8,8));P (Red,(1,7));P (Red,(3,7));P (Red,(5,7));
      P (Red,(7,7));P (Red,(2,6));P (Red,(4,6));P (Red,(6,6));
      P (Red,(8,6))
    ];
    turn = 1; 
  }

(** [in bounds coords] is whether [coords] is in bounds of the board. *)
let in_bounds coords = 
  fst coords >= 1 && fst coords <= 8 && snd coords <= 8 && snd coords >= 1

(** [get_color piece] returns the color of [piece]. *)
let get_color = function
  | K (color, _)
  | P (color, _) -> color

(** [get_color piece] returns the coordinates of [piece]. *)
let get_coords = function
  | K (_, coords)
  | P (_, coords) -> coords

let check_win st = 
  failwith("unimplemented")

(** [piece_at coords piece_lst] is an option, Some p where piece from 
    [piece_lst] that has coordinates [coords] or None if no pieces match the 
    coordinates [coords]. *)
let rec piece_at coords piece_lst = 
  match piece_lst with
  | [] -> None
  | ((P (_, coords')) as p):: t when coords = coords' -> Some p 
  | ((K (_, coords')) as p):: t when coords = coords' -> Some p
  | _ :: t -> piece_at coords t

(** [get_normal_moves piece piece_lst] is a list of of moves that a piece
    [piece] can take without jumping given piece list [piece_lst]. *)
let get_normal_moves piece piece_lst = 
  let helper start p_lst color = 
    let ydif = if color = Red then ~-1 else 1 in 
    let (x,y) = start in 
    List.map (fun el -> [(x,y); el])
      (List.filter (fun pos -> in_bounds pos && piece_at pos p_lst = None) 
         [(x - 1, y + ydif); (x + 1, y + ydif)]) in
  match piece with 
  | P (color, (x,y)) -> helper (x,y) piece_lst color
  | K (_, (x,y)) -> 
    helper (x,y) piece_lst Red @ helper (x,y) piece_lst Black

let taken_piece start dest color piece_lst = 
  let in_between = ((fst start + fst dest) / 2, (snd start + snd dest)/2) in 
  if in_bounds dest && (piece_at dest piece_lst) = None then 
    match piece_at in_between piece_lst with
    | None -> None
    | Some piece -> if (get_color piece) <> color then (Some in_between) else None
  else None

let get_jump_paths piece piece_lst = 
  let helper start p_lst color = 
    let ydif = if color = Red then ~-2 else 2 in 
    let (x,y) = start in 
    (List.filter (fun pos -> (taken_piece start pos color p_lst) <> None) 
       [(x - 2, y + ydif); (x + 2, y + ydif)]) in
  match piece with 
  | P (color, (x,y)) -> helper (x,y) piece_lst color 
  | K (_, (x,y)) -> 
    helper (x,y) piece_lst Red  @ 
    helper (x,y) piece_lst Black  

let rec remove_piece_w_coords coords acc = function 
  | [] -> acc
  | h::t when coords = get_coords h -> acc@t
  | h::t -> remove_piece_w_coords coords (h::acc) t

let get_jump_moves piece piece_lst = 
  let rec helper p p_lst curr_path cmp_paths = 
    let c = get_color p in 
    match get_jump_paths p p_lst with 
    | [] -> curr_path::cmp_paths
    | h :: t -> 
      let p' = match p with 
        | K _-> K (c, h)
        | P _-> P (c, h) in 
      let p_lst' = remove_piece_w_coords h [] p_lst in
      helper p' p_lst' (curr_path@[h]) cmp_paths
  in helper piece piece_lst [] []


(** A move is valid if:
    - check if desired destination is empty 
    - if not a king, check if piece is moving diagonally (left/right) forward one spot 
        AND if there are no available forward jumps to make 
    - if king, check if piece is moving diagonally (left/right) forward/backward one spot
        AND if there are no availble forward/backward jumps to make 
    - check if player jumps over all possible pieces 
    - "move" command can also be interpreted as a "jump" command, but 
        "jump" command MUST only be jumping over opponent's pieces. *)
let get_all_moves st = 
  let color = if st.turn mod 2 = 0 then Red else Black in 
  let rec add_jump_moves c p_lst acc = 
    match p_lst with 
    | [] -> acc
    | h::t -> 
      add_jump_moves c t ((get_jump_moves h st.pieces) @ acc) in 
  let rec add_normal_moves c p_lst acc = 
    match p_lst with 
    | [] -> acc 
    | h::t -> 
      add_normal_moves c t ((get_normal_moves h st.pieces) @ acc) in 
  let moves = add_jump_moves color st.pieces [] in 
  if List.length moves = 0 then add_normal_moves color st.pieces moves 
  else moves



(** [get_score st points] gets the current number of black pieces minus the 
    current number of red pieces. *)
let get_score st = 
  let rec helper acc = function
    | [] -> acc
    | K (color, _)::t 
    | P (color, _)::t -> 
      if color = Black then helper (acc + 1) t else  helper (acc - 1) t
  in helper 0 st.pieces

(** [piece_at coords piece_lst] is an option, Some p where piece from 
    [piece_lst] that has coordinates [coords] or None if no pieces match the 
    coordinates [coords]. *)
let rec piece_at coords piece_lst = 
  match piece_lst with
  | [] -> None
  | ((P (_, coords')) as p) :: t when coords = coords' -> Some p
  | ((K (_, coords')) as p) :: t when coords = coords' -> Some p
  | _ :: t -> piece_at coords t

(** [piece_lst_helper st mv] is the tuple of the list of piece coordinates to be 
    removed after performing move [mv] on state [st] with list of piece 
    coordinates to be removed [acc] and the last coordinate in [mv].

    Requires: [mv] is a valid move. 
*)
let rec piece_lst_helper mv acc = 
  match mv with 
  | [] -> failwith("You have a move with no elements. This shouldn't happen")
  | h :: [] -> acc
  | (x1,y1) :: (x2,y2) :: t -> 
    if abs (y2-y1) = 2 
    then piece_lst_helper ((x2,y2)::t) (((x2+x1)/2, (y1+y2)/2)::acc)
    else piece_lst_helper ((x2,y2)::t) acc 


(** [remove_pieces remove_lst piece_lst] is [piece_lst] without pieces that have
    coordinates in [remove_lst] .*)
let rec remove_pieces remove_lst piece_lst acc = 
  match piece_lst with
  | [] -> acc
  | ((K (_, coord)) as h) :: t 
  | ((P (_, coord)) as h) :: t -> 
    if List.mem coord remove_lst then remove_pieces remove_lst t acc 
    else remove_pieces remove_lst t (h :: acc)

(** [update_piece_list p_lst mv] is the new piece list after performing move [mv] 
    with piece list [piece_lst]. 
    Requires: [mv] is a valid move. *)
let update_piece_list piece_lst mv = 
  let remove_lst = piece_lst_helper mv [] in 
  let final_dest = List.(hd (rev mv)) in 
  let my_piece = piece_at (List.hd mv) piece_lst in 
  let new_piece = 
    match my_piece with 
    | None -> failwith("invalid move in update_piece_list")
    | Some (K (color, _)) -> K (color,final_dest)
    | Some (P (color, _)) -> 
      if (snd final_dest = 8 && color = Black) 
      || (snd final_dest = 1 && color = Red) then K (color, final_dest) 
      else P(color, final_dest) in
  let updated_list = remove_pieces remove_lst piece_lst [] in 
  new_piece :: updated_list

(** TODO 
    [move st mv] is the result of attempting to make the move(s) specified by [mv]
    If the move is legal, then the result is [Legal st'] where [st'] is the 
    new state after taking the move [mv] in the state [st]. Otherwise, the 
    result is [Illegal] 
    Other functionalities: 
    - check if piece at can be crowned. *)
let move st mv = 
  if List.mem mv (get_all_moves st) then 
    let st' = {pieces = update_piece_list st.pieces mv; turn = st.turn + 1} in 
    Legal st'
  else Illegal 


(*** TODO
     To discuss: shouldn't printing to terminal be handled in main instead of
     in game? 
     [print_prompt] displays the correct prompt and the available commands for 
     current game state, see command.ml for Menu Levels.
     Example: "Player 1 offered a draw, would you like to accept or reject?"
     "Player 2 played (x1,y1) to (x2,y2). It is now Player 1's turn." 
     "Both players have agreed on a draw, game over."
     "Player 1 Won!" 
     "50 move limit has been reached. Game Oh-vah", etc *)

let print_prompt = 
  failwith "unimplemented"

let print_row coords subrow piece=
  begin
    match (coords,subrow,piece) with
    | (x,y),_,None | _, 1, Some P (Red, (x,y)) |_, 1, Some P (Black, (x,y)) 
    | _, 5, Some P (Red, (x,y)) | _, 5, Some P (Black, (x,y)) 
    | _, 5, Some K (Red, (x,y)) | _, 5, Some K (Black, (x,y)) when (x+y) mod 2=1
      -> ANSITerminal.(print_string [on_red] "          ");
    | (x,y),_,None | _, 1, Some P (Red, (x,y)) | _, 1, Some P (Black, (x,y)) 
    | _, 5, Some P (Red, (x,y)) | _, 5, Some P (Black, (x,y))
    | _, 5, Some K (Red, (x,y)) | _, 5, Some K (Black, (x,y)) when (x+y) mod 2=0 
      -> ANSITerminal.(print_string [on_black] "          ");
    | _, 2, Some P (Black, c)
      -> ANSITerminal.(print_string [on_black] "  /");
      ANSITerminal.(print_string [on_white] "    ");
      ANSITerminal.(print_string [on_black] "\\  ");
    | _, 4, Some P (Black, c)
      -> ANSITerminal.(print_string [on_black] "  \\");
      ANSITerminal.(print_string [on_white] "    ");
      ANSITerminal.(print_string [on_black] "/  ");
    | _, 2, Some P (Red, c)
      -> ANSITerminal.(print_string [on_black;magenta] "  /");
      ANSITerminal.(print_string [on_magenta] "    ");
      ANSITerminal.(print_string [on_black;magenta] "\\  ");
    | _, 4, Some P (Red, c)
      -> ANSITerminal.(print_string [on_black;magenta] "  \\");
      ANSITerminal.(print_string [on_magenta] "    ");
      ANSITerminal.(print_string [on_black;magenta] "/  ");
    | _, 3, Some P (Black, c)
      -> ANSITerminal.(print_string [on_black] "  ");
      ANSITerminal.(print_string [on_white] "      ");
      ANSITerminal.(print_string [on_black] "  ");
    | _, 3, Some P (Red, c) 
      -> ANSITerminal.(print_string [on_black] "  ");
      ANSITerminal.(print_string [on_magenta] "      ");
      ANSITerminal.(print_string [on_black] "  ");
      (*King's Crown*)
    | _, 1, Some K (Black, (x,y))
      -> ANSITerminal.(print_string [on_black] "  \\");
      ANSITerminal.(print_string [on_black;Underlined] "/\\/\\");
      ANSITerminal.(print_string [on_black] "/  ");
    | _, 1, Some K (Red, (x,y))
      -> ANSITerminal.(print_string [on_black;magenta] "  \\");
      ANSITerminal.(print_string [on_black;magenta;Underlined] "/\\/\\");
      ANSITerminal.(print_string [on_black;magenta] "/  ");
      (*Extra fun*)
    | _, 2, Some K (Black, c)
      -> ANSITerminal.(print_string [on_black] "  /");
      ANSITerminal.(print_string [on_white; red] "HIDE");
      ANSITerminal.(print_string [on_black] "\\  ");
    | _, 3, Some K (Black, c) 
      -> ANSITerminal.(print_string [on_black] "  ");
      ANSITerminal.(print_string [on_white; red] "  YO  ");
      ANSITerminal.(print_string [on_black] "  ");
    | _, 4, Some K (Black, c) 
      -> ANSITerminal.(print_string [on_black] "  \\");
      ANSITerminal.(print_string [on_white; red] "KIDS");
      ANSITerminal.(print_string [on_black] "/  ");
    | _, 2, Some K (Red, c)
      -> ANSITerminal.(print_string [on_black;magenta] "  /");
      ANSITerminal.(print_string [on_magenta] "HIDE");
      ANSITerminal.(print_string [on_black;magenta] "\\  ");
    | _, 3, Some K (Red, c) 
      -> ANSITerminal.(print_string [on_black] "  ");
      ANSITerminal.(print_string [on_magenta] "  YO  ");
      ANSITerminal.(print_string [on_black] "  ");
    | _, 4, Some K (Red, c) 
      -> ANSITerminal.(print_string [on_black;magenta] "  \\");
      ANSITerminal.(print_string [on_magenta] "WIFE");
      ANSITerminal.(print_string [on_black;magenta] "/  ");
    | _ -> failwith "idk"
  end



let print_board pieces = 
  for col=1 to 8 do
    for subrow=1 to 5 do
      let col' = 9-col in
      if subrow = 3
      then begin print_string " "; print_int (col'); print_string "  "; end
      else print_string "    ";
      for row=1 to 8 do
        print_row (col',row) subrow (piece_at (row,col') pieces);
      done;
      print_string "\n"
    done;
  done;
  print_string "\n    ";
  print_string "    a     ";
  print_string "    b     ";
  print_string "    c     ";
  print_string "    d     ";
  print_string "    e     ";
  print_string "    f     ";
  print_string "    g     ";
  print_string "    h     \n\n";