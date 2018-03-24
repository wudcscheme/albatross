module type ANY =
  sig
    type t
  end


module Either =
  struct
    type ('a,'b) t =
      | Left of 'a
      | Right of 'b
    let left a = Left a
    let right b = Right b
  end


module Char_ =
  struct
    include Char
    let is_lower (c:char): bool =
      'a' <= c && c <= 'z'
    let is_upper (c:char): bool =
      'A' <= c && c <= 'Z'
    let is_letter (c:char): bool =
      is_lower c || is_upper c
    let is_digit (c:char): bool =
      '0' <= c && c <= '9'
  end

module String_ =
  struct
    include String

    let one (c:char): string =
      String.make 1 c

    let list (s:string): char list =
      let rec list cs i =
        if i = 0 then
          cs
        else
          let j = i - 1 in
          list (s.[j]::cs) j
      in
      list [] (length s)

    let of_list (cs:char list): string =
      let rec str cs i =
        match cs with
        | [] ->
           Bytes.create i
        | c::cs ->
           let bs = str cs (i+1) in
         Bytes.set bs i c;
         bs
      in
      let bs = str cs 0 in
      Bytes.unsafe_to_string bs
  end
