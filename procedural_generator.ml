open Actors
open Object

type obj_coord =  int * (float * float)

(*Set boundary variables*)
(*Max height Mario can jump*)
let max_jump = 3;;

(*Max distance Mario can jump*)
let max_dist = 3;;

(*Height of ground based on number of grids*)
let ground_height = 2;;

(*Canvas is 512 by 256 (w*h) -> 32 by 16 blocks
* Let the first generaed map just be of size 5 by 5 blocks *)

(*Checks if the given location checkloc is already part of the list of locations
* in loclist.*)
let rec mem_loc (checkloc: float * float) (loclist: obj_coord list) : bool =
  match loclist with
  |[] -> false
  |h::t -> if (checkloc = (snd h)) then true
           else mem_loc checkloc t

(*Converts list of locations from blocksize to pixelsize by multiplying (x,y) by
16*)
let rec convert_list (lst:obj_coord list) :obj_coord list =
  match lst with
  |[] -> []
  |(h::t) -> [(fst h, ((fst (snd h))*.16.,(snd (snd h))*.16.))]@(convert_list t)

(*Chooses what type of enemy should be instantiated given typ number*)
let choose_enemy_typ (typ:int) : enemy_typ =
  match typ with
  |0 -> RKoopa
  |1 -> GKoopa
  |2 -> Goomba
  |_ -> failwith "Shouldn't reach here"

(*Chooses what type of block should be instantiated given typ number*)
let choose_sblock_typ (typ:int) : block_typ =
  match typ with
  |0 -> Brick
  |1 -> UnBBlock
  |2 -> Cloud
  |3 -> QBlock Mushroom
  |_ -> failwith "Shouldn't reach here"

(*Optimizes lst such that there are no two items in the list that have the same
* coordinates. If there is one, it is removed.*)
let rec avoid_overlap (lst:obj_coord list) (currentLst:obj_coord list)
                      : obj_coord list =
  match lst with
  |[] -> []
  |h::t -> if(mem_loc (snd h) currentLst) then avoid_overlap t currentLst
           else [h]@(avoid_overlap t currentLst)

(*Generates a stair formation with block typ being dependent on typ. This type
* of stair formation requires that the first step be on the ground.*)
let generate_ground_stairs cbx cby typ =
  let four = [(typ, (cbx, cby));(typ, (cbx+.1., cby));(typ, (cbx+.2., cby));
             (typ, (cbx+.3., cby))] in
  let three = [(typ,(cbx +. 1., cby -. 1.));(typ,(cbx +. 2., cby -. 1.));
              (typ,(cbx +. 3., cby -. 1.))] in
  let two = [(typ,(cbx +. 2., cby -. 2.));(typ,(cbx +. 3., cby -. 2.))] in
  let one = [(typ,(cbx +. 3., cby -. 3.))] in
  four@three@two@one

(*Generates a stair formation going upwards with the starting step not being
* on the ground.*)
let generate_airup_stairs cbx cby typ =
  let one = [(typ,(cbx, cby));(typ,(cbx +. 1., cby));(typ,(cbx +. 2., cby))] in
  let two = [(typ,(cbx +. 2., cby -. 1.));(typ,(cbx +. 3., cby -. 1.));
            (typ,(cbx +. 4., cby -. 1.))] in
  let three = [(typ,(cbx +. 4., cby -. 2.));(typ,(cbx +. 5., cby -. 2.));
              (typ,(cbx +. 6., cby -. 2.))] in
  one@two@three

(*Generates a stair formation going downwards with the starting step not being
* on the ground. *)
let generate_airdown_stairs cbx cby typ =
  let three = [(typ,(cbx, cby));(typ,(cbx +. 1., cby));(typ,(cbx +. 2., cby))]in
  let two = [(typ,(cbx +. 2., cby +. 1.));(typ,(cbx +. 3., cby +. 1.));
            (typ,(cbx +. 4., cby +. 1.))] in
  let one = [(typ,(cbx +. 4., cby +. 2.));(typ,(cbx +. 5., cby +. 2.));
            (typ,(cbx +. 6., cby +. 2.))] in
  three@two@one

(*Generates a cloud block platform with some length num.*)
let rec generate_clouds cbx cby typ num =
  if(num = 0) then []
  else [(typ,(cbx, cby))]@generate_clouds (cbx+.1.) cby typ (num-1)

(*Chooses the form of the blocks to be placed.
* When called, leaves a 1 block gap from canvas size.
* 1. If current xblock or yblock is greater than canvas width or height
*    respectively, return an empty list.
* 2. If current xblock or yblock is within 10 blocks of the left and right sides
*    of the level map, prevent any objects from being initialized.
* 3. Else call helper methods to created block formations and return obj_coord
*    list.
**)
let choose_block_pattern (blockw:float) (blockh: float) (cbx:float) (cby:float)
                         (prob:int) : obj_coord list=
  if(cbx > blockw || cby > blockh) then []
  else if (cbx < 10. || blockw -. cbx < 10.) then []
  else
    let block_typ = Random.int 4 in
    let stair_typ = Random.int 2 in
    match prob with
    |0 -> if(blockw -. cbx = 2.) then [(block_typ, (cbx, cby));
            (block_typ,(cbx +. 1., cby));(block_typ,(cbx +. 2., cby))]
          else if (blockw -. cbx = 1.) then [(block_typ,(cbx, cby));
            (block_typ,(cbx +. 1., cby))]
          else [(block_typ,(cbx, cby))]
    |1 -> let num_clouds = Random.int 10 in
          if(cby < 5.) then generate_clouds cbx cby 2 num_clouds
          else []
    |2 -> if(blockh-.cby = 1.) then generate_ground_stairs cbx cby stair_typ
          else []
    |3 -> if(stair_typ = 0 && blockh -. cby > 3.) then
          generate_airdown_stairs cbx cby stair_typ
          else generate_airup_stairs cbx cby stair_typ
    |4 -> if ((cby +. 3.) -. blockh = 2.) then [(stair_typ,(cbx, cby))]
          else if ((cby +. 3.) -. blockh = 1.) then [(stair_typ, (cbx,cby));
          (stair_typ, (cbx, cby +. 1.))]
          else [(stair_typ,(cbx, cby)); (stair_typ,(cbx, cby +. 1.));
          (stair_typ,(cbx, cby +. 2.))]
    |5 -> [(3,(cbx, cby))]
    |_ -> failwith "Shouldn't reach here"

(*Generates an obj_coord list (typ, coordinates) of enemies to be placed.*)
let rec generate_enemies (blockw: float) (blockh: float) (cbx: float)
                    (cby: float) (acc: obj_coord list) =
  if(cbx > blockw) then []
  else if (cby > (blockh-. 1.)) then
    generate_enemies blockw blockh (cbx +. 1.) 0. acc
  else if(mem_loc (cbx, cby) acc) then
    generate_enemies blockw blockh cbx (cby+.1.) acc
  else
    let prob = Random.int 100 in
    let enem_prob = 3 in
      if(prob < enem_prob) then
        let enemy = [(prob,(cbx,cby))] in
        enemy@(generate_enemies blockw blockh cbx (cby+.1.) acc)
      else generate_enemies blockw blockh cbx (cby+.1.) acc

(*Generates an obj_coord list (typ, coordinates) of blocks to be placed.*)
let rec generate_block_locs (blockw: float) (blockh: float) (cbx: float)
                    (cby: float) (acc: obj_coord list) : obj_coord list =
  if(cbx > blockw) then acc
  else if (cby > (blockh-. 1.)) then
    generate_block_locs blockw blockh (cbx+.1.) 0. acc
  else if(mem_loc (cbx, cby) acc) then
    generate_block_locs blockw blockh cbx (cby+.1.) acc
  else
    let prob = Random.int 100 in
    let block_prob = 5 in
      if(prob < block_prob) then
        let newacc = choose_block_pattern blockw blockh cbx cby prob in
        let undup_lst = avoid_overlap newacc acc in
        let called_acc = acc@undup_lst in
        generate_block_locs blockw blockh cbx (cby+.1.) called_acc
      else generate_block_locs blockw blockh cbx (cby+.1.) acc

let rec generate_items (blockw: float) (blockh: float) (cbx:float)
                       (cby: float) (acc: obj_coord list) : obj_coord list =
  if(cbx > blockw) then []
  else if (cby > (blockh -. 1.)) then
    generate_items blockw blockh (cbx +. 1.) 0. acc
  else if (mem_loc (cbx, cby) acc) then
    generate_items blockw blockh cbx (cby +. 1.) acc
  else
    let prob = Random.int 100 in
    let item_prob = 10 in
      if(prob < item_prob) then
        let item = [(0,(cbx,cby))] in
        item@(generate_items blockw blockh cbx (cby +. 1.) acc)
      else generate_items blockw blockh cbx (cby +. 1.) acc

(*Generates the list of brick locations needed to display the ground.
* 1/10 chance that a ground block is skipped each call.*)
let rec generate_ground (blockw:float) (blockh:float) (inc:float)
                        (acc: obj_coord list) : obj_coord list =
  if(inc > blockw) then acc
  else
    if(inc > 10.) then
      let skip = Random.int 10 in
      let newacc = acc@[(1, (inc*. 16.,blockh *. 16.))] in
      if (skip = 7) then generate_ground blockw blockh (inc +. 1.) acc
      else  generate_ground blockw blockh (inc +. 1.) newacc
    else let newacc = acc@[(1, (inc*. 16.,blockh *. 16.))] in
      generate_ground blockw blockh (inc +. 1.) newacc

(*Converts the obj_coord list called by generate_block_locs to a list of objects
* with the coordinates given from the obj_coord list. *)
let rec convert_to_block_obj (lst:obj_coord list)
  (context:Dom_html.canvasRenderingContext2D Js.t) : collidable list =
  match lst with
  |[] -> []
  |h::t ->
    let sblock_typ = choose_sblock_typ (fst h) in
    let ob = Object.spawn (SBlock sblock_typ) context (snd h) in
    [ob]@(convert_to_block_obj t context)

(*Converts the obj_coord list called by generate_enemies to a list of objects
* with the coordinates given from the obj_coord list. *)
let rec convert_to_enemy_obj (lst:obj_coord list)
            (context:Dom_html.canvasRenderingContext2D Js.t) : collidable list =
  match lst with
  |[] -> []
  |h::t ->
    let senemy_typ = choose_enemy_typ (fst h) in
    let ob = Object.spawn (SEnemy senemy_typ) context (snd h) in
    [ob]@(convert_to_enemy_obj t context)

let rec convert_to_item_obj (lst:obj_coord list)
            (context:Dom_html.canvasRenderingContext2D Js.t) : collidable list =
  match lst with
  |[] -> []
  |h::t ->
    let sitem_typ = Coin in
    let ob = Object.spawn (SItem sitem_typ) context (snd h) in
    [ob]@(convert_to_item_obj t context)

(*Procedurally generates a map given canvas width, height and context*)
let generate_helper (blockw:float) (blockh:float) (cx:float) (cy:float)
            (context:Dom_html.canvasRenderingContext2D Js.t) : collidable list =
  let block_locs = generate_block_locs blockw blockh 0. 0. [] in
  let converted_block_locs = convert_list block_locs in
  let obj_converted_block_locs = convert_to_block_obj converted_block_locs
    context in
  let ground_blocks = generate_ground blockw blockh 0. [] in
  let obj_converted_ground_blocks = convert_to_block_obj ground_blocks
    context in
  let block_locations = block_locs@ground_blocks in
  let all_blocks = obj_converted_block_locs@obj_converted_ground_blocks in
  let enemy_locs = generate_enemies blockw blockh 0. 0. block_locations in
  let obj_converted_enemies = convert_to_enemy_obj enemy_locs context in
  let all_taken = block_locations@enemy_locs in
  let item_locs = generate_items blockw blockh 0. 0. all_taken in
  let obj_converted_items = convert_to_item_obj item_locs context in
  all_blocks@obj_converted_enemies@obj_converted_items

(*Main function called to procedurally generate the level map.*)
let generate (blockw:float) (blockh:float)
                    (context:Dom_html.canvasRenderingContext2D Js.t) :
                    (collidable * collidable list) =
  let collide_list = generate_helper blockw blockh 0. 0. context in
  let player = Object.spawn (SPlayer(SmallM,Standing)) context (100.,224.) in
  (player, collide_list)

(*Makes sure level map is uniquely generated at each call.*)
let init () =
  Random.self_init();