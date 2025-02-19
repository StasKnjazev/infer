(*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

(** Formulas *)

module Prop = Propositional.Make (Trm)
module Set = Prop.Fmls
include Prop.Fml

let pp_boxed fs fmt =
  Format.pp_open_box fs 2 ;
  Format.kfprintf (fun fs -> Format.pp_close_box fs ()) fs fmt

let ppx strength fs fml =
  let pp_t = Trm.ppx strength in
  let pp_a = Trm.Arith.ppx pp_t in
  let rec pp fs fml =
    let pf fmt = pp_boxed fs fmt in
    let pp_binop x = pf "(%a@ @<2>%s %a)" x in
    let pp_arith_op x op y =
      let flip = Trm.Arith.compare x y > 0 in
      let x, y = if flip then (y, x) else (x, y) in
      match op with
      | ">" -> pp_binop pp_a x (if flip then "<" else ">") pp_a y
      | "≤" -> pp_binop pp_a x (if flip then "≥" else "≤") pp_a y
      | op -> pp_binop pp_a x op pp_a y
    in
    let pp_arith op x =
      let p_c, n_d = Trm.Arith.partition_sign (Trm.Arith.trm x) in
      if Trm.Arith.equal (Trm.Arith.const Q.zero) p_c then
        let n, d = Trm.Arith.split_const n_d in
        pp_arith_op n op (Trm.Arith.const (Q.neg d))
      else if Trm.Arith.equal (Trm.Arith.const Q.zero) n_d then
        let p, c = Trm.Arith.split_const p_c in
        pp_arith_op p op (Trm.Arith.const (Q.neg c))
      else pp_arith_op p_c op n_d
    in
    let pp_join sep pos neg =
      pf "(%a%t%a)" (Set.pp_full ~sep pp) pos
        (fun ppf ->
          if (not (Set.is_empty pos)) && not (Set.is_empty neg) then
            Format.fprintf ppf sep )
        (Set.pp_full ~sep (fun fs fml -> pp fs (_Not fml)))
        neg
    in
    match fml with
    | Tt -> pf "tt"
    | Not Tt -> pf "ff"
    | Eq (x, y) -> pp_binop pp_t x "=" pp_t y
    | Not (Eq (x, y)) -> pp_binop pp_t x "≠" pp_t y
    | Distinct xs -> pf "(%a)" (Array.pp "@ ≠ " pp_t) xs
    | Eq0 x -> pp_arith "=" x
    | Not (Eq0 x) -> pp_arith "≠" x
    | Pos x -> pp_arith ">" x
    | Not (Pos x) -> pp_arith "≤" x
    | Not x -> pf "@<1>¬%a" pp x
    | And {pos; neg} -> pp_join "@ @<2>∧ " pos neg
    | Or {pos; neg} -> pp_join "@ @<2>∨ " pos neg
    | Iff (x, y) -> pf "(%a@ <=> %a)" pp x pp y
    | Cond {cnd; pos; neg} ->
        pf "@[<hv 1>(%a@ ? %a@ : %a)@]" pp cnd pp pos pp neg
    | Lit (p, xs) -> pf "%a(%a)" Predsym.pp p (Array.pp ",@ " pp_t) xs
  in
  pp fs fml

let pp = ppx (fun _ -> None)

(** Construct *)

let tt = mk_Tt ()
let ff = _Not tt
let bool b = if b then tt else ff

let _Eq0 x =
  match (x : Trm.t) with
  | Z z -> bool (Z.equal Z.zero z)
  | Q q -> bool (Q.equal Q.zero q)
  | x -> _Eq0 x

let _Pos x =
  match (x : Trm.t) with
  | Z z -> bool (Z.gt z Z.zero)
  | Q q -> bool (Q.gt q Q.zero)
  | x -> _Pos x

let sort_eq x y =
  match Sign.of_int (Trm.compare x y) with
  | Neg -> _Eq x y
  | Zero -> tt
  | Pos -> _Eq y x

let _Eq x y =
  if x == Trm.zero then _Eq0 y
  else if y == Trm.zero then _Eq0 x
  else
    match (x, y) with
    (* x = y ==> 0 = x - y when x = y is an arithmetic equality *)
    | (Z _ | Q _ | Arith _), _ | _, (Z _ | Q _ | Arith _) ->
        _Eq0 (Trm.sub x y)
    (* α^β^δ = α^γ^δ ==> β = γ *)
    | Concat a, Concat b ->
        let length_a = Array.length a in
        let length_b = Array.length b in
        let min_length = min length_a length_b in
        let length_common_prefix =
          let rec find_lcp i =
            if i < min_length && Trm.equal_sized a.(i) b.(i) then
              find_lcp (i + 1)
            else i
          in
          find_lcp 0
        in
        let min_length_without_common_prefix =
          min_length - length_common_prefix
        in
        let length_common_suffix =
          let rec find_lcs i =
            if
              i < min_length_without_common_prefix
              && Trm.equal_sized a.(length_a - 1 - i) b.(length_b - 1 - i)
            then find_lcs (i + 1)
            else i
          in
          find_lcs 0
        in
        let length_common = length_common_prefix + length_common_suffix in
        if length_common = 0 then sort_eq x y
        else
          let len_a = length_a - length_common in
          let len_b = length_b - length_common in
          if len_a = 0 && len_b = 0 then tt
          else
            let pos = length_common_prefix in
            let a = Array.sub ~pos ~len:len_a a in
            let b = Array.sub ~pos ~len:len_b b in
            _Eq (Trm.concat a) (Trm.concat b)
    | _ -> sort_eq x y

let _Distinct xs =
  match Array.length xs with
  | 0 | 1 -> tt
  | 2 -> _Not (sort_eq xs.(0) xs.(1))
  | _ ->
      Array.sort ~cmp:Trm.compare xs ;
      if Array.contains_adjacent_duplicate ~eq:Trm.equal xs then ff
      else _Distinct xs

let eq = _Eq
let distinct = _Distinct
let eq0 = _Eq0
let pos = _Pos
let not_ = _Not
let and_ = and_
let andN = _And
let or_ = or_
let orN = _Or
let iff = _Iff
let cond ~cnd ~pos ~neg = _Cond cnd pos neg
let lit = _Lit

let rec map_trms b ~f =
  match b with
  | Tt -> b
  | Eq (x, y) -> map2 f b _Eq x y
  | Distinct xs -> mapN f b _Distinct xs
  | Eq0 x -> map1 f b _Eq0 x
  | Pos x -> map1 f b _Pos x
  | Not x -> map1 (map_trms ~f) b _Not x
  | And {pos; neg} -> map_and b ~pos ~neg (map_trms ~f)
  | Or {pos; neg} -> map_or b ~pos ~neg (map_trms ~f)
  | Iff (x, y) -> map2 (map_trms ~f) b _Iff x y
  | Cond {cnd; pos; neg} -> map3 (map_trms ~f) b _Cond cnd pos neg
  | Lit (p, xs) -> mapN f b (_Lit p) xs

let map_vars b ~f = map_trms ~f:(Trm.map_vars ~f) b

(** Traverse *)

let fold_pos_neg ~pos ~neg s ~f =
  let f_not p s = f (not_ p) s in
  Set.fold ~f:f_not neg (Set.fold ~f pos s)

let iter_pos_neg ~pos ~neg ~f =
  let f_not p = f (not_ p) in
  Set.iter ~f pos ;
  Set.iter ~f:f_not neg

let iter_dnf ~meet1 ~top fml ~f vx =
  let rec add_conjunct fml (cjn, splits) vx =
    match fml with
    | Tt | Eq _ | Distinct _ | Eq0 _ | Pos _ | Iff _ | Lit _ | Not _ ->
        let cjn = meet1 fml cjn vx in
        (cjn, splits)
    | And {pos; neg} ->
        fold_pos_neg ~pos ~neg (cjn, splits) ~f:(fun fml cjn_splits ->
            add_conjunct fml cjn_splits vx )
    | Or {pos; neg} ->
        let splits = (pos, neg) :: splits in
        (cjn, splits)
    | Cond {cnd; pos; neg} ->
        let cjt = or_ (and_ cnd pos) (and_ (not_ cnd) neg) in
        add_conjunct cjt (cjn, splits) vx
  in
  let rec add_disjunct (cjn, splits) fml vx =
    let cjn, splits = add_conjunct fml (cjn, splits) vx in
    let vx = !vx in
    match splits with
    | (pos, neg) :: splits ->
        iter_pos_neg ~pos ~neg ~f:(fun fml ->
            Var.Fresh.gen_ vx (add_disjunct (cjn, splits) fml) )
    | [] -> f (cjn, vx)
  in
  add_disjunct (top, []) fml vx

let dnf ~meet1 ~top fml vx =
  Iter.from_iter (fun f -> iter_dnf ~meet1 ~top fml ~f vx)

let vars p = Iter.flat_map ~f:Trm.vars (trms p)
