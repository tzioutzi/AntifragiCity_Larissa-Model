;;;;;**************** TRAFFIC MOVEMENT MODEL *********************;;;;
;;;;;                                                             ;;;;
;;;;; This model simulates a general evacuation scenario with     ;;;;
;;;;; capability of adding destinations and                       ;;;;
;;;;; simulating transportation network damage and road closures. ;;;;
;;;;; This model is developed by Alireza Mostafizi and under      ;;;;
;;;;; direct supervision of Dr. Haihzong Wang, Dr. Dan Cox, and   ;;;;
;;;;; Dr. Lori Cramer from Oregon State University. If you use    ;;;;
;;;;; this model to any extent, we ask you to cite our relevant   ;;;;
;;;;; publications listed in the Readme file of the repository.   ;;;;
;;;;;                                                             ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;; EXTENSIONS ;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

extensions [
  gis   ; the GIS extension is required to load the 1. road network
        ;                                           2. travel destinations
        ;                                       and 3. population distribution

]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;; BREEDS ;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

breed [ residents resident]              ; the evacuees before they make it to the transportation network
breed [ cars car ]                       ; a resident will turn to a car (after they make it to the transportation network) if they decided to drive to the destination
breed [ buses bus ]                      ; a resident will turn to a bus (after they make it to the transportation network)
breed [ intersections intersection ]     ; intersections are treated as agents
breed [ bus_stops bus_stop ]             ; bus stops along the route are treated as agents

directed-link-breed [ roads road ]       ; roads are treated as directed links between the intersection (e.g, two directed links between a pair of intersections if the road is two-way)
directed-link-breed [bus_lanes bus_lane] ; bus lanes treated as directed links between the bus stops
directed-link-breed [ evacs evac ]       ; evacuation of vulnerable population as tied directed links between the responders and the evacuees

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;; VARIABLES ;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

patches-own [    ; the variables that patches own
  flooded?       ; true if patch is a flooded area, false if not
  depth          ; current flood depth
  max_depth      ; maximum depth of flood over time at the end of simulation
]

residents-own [  ; the variables that residents own
  init_dest      ; initial destination, the closest intersection to the agent at the start of simulation
  reached?       ; true if the agent is reached to the init_dest and ready to turn to pedestrian or car, false if not
  current_int    ; current/previous intersection of an agent, 0 if none
  moving?        ; true if the agent is moving, false if not
  arrived?       ; true if an agent has arrived to the destination
                 ; if the simulation is ended and the agent is not caught by the tsunami
  speed          ; speed of the agent, measured in patches per tick
  decision       ; the agents decision code: 1 for Hor Evac on foot
                 ;                           2 for Hor Evac by Car
                 ;                           3 for Ver Evac on foot
                 ;                           4 for Ver Evac by Car
  miltime        ; the agents milling time (preparation time before the evacuation starts) referenced from the evacuation signal
                 ; measureed in seconds
  vulnerable?    ; true if the agent is vulnerable (speed < 0.1 m/s), false if not
  collected?     ; true if the agent is collected for evacuation from the responders, false if not
  income         ; average monthly income (after taxes) in the city of Larissa

]

roads-own [      ; the variables that roads own
  crowd          ; number of people on foot on each link at any time
  traffic        ; number of cars on each link at any time
  mid-x          ; xcor of the middle point of a link, in patches
  mid-y          ; ycor of the middle point of a link, in patches
]

bus_lanes-own [  ; the variables that roads own
  crowd          ; number of people on foot on each link at any time
  traffic        ; number of cars on each link at any time
  mid-x          ; xcor of the middle point of a link, in patches
  mid-y          ; ycor of the middle point of a link, in patches
]

intersections-own [ ; the variables that intersections own
  destination?      ; true if there is a destination at an interseciton, flase if not
  destination_type  ; string representing the type of the destination
  id                ; a unique id associated to each intersection (0 to number of intersections - 1)
  previous          ; for calculating the shortest path from each intersection to the a destination (A* Alg)
  fscore            ; for calculating the shortest path from each intersection to the a destination (A* Alg)
  gscore            ; for calculating the shortest path from each intersection to the a destination (A* Alg)
  car-path          ; best path from an intersection to the horizontal destination (list of intersection 'who's)
  evacuee_count     ; the number of agents that are arrived at an intersection, if there is a destination in it
  vuln_count        ; the number of vulnerable agents arrived at an intersection, if there is a destination in it
]

bus_stops-own     [ ; the variables that intersections own
  destination?      ; true if there is a destination at a bus stop, flase if not
  destination_type  ; string representing the type of the destination,
  id                ; a unique id associated to each intersection (0 to number of intersections - 1)
  bprevious          ; for calculating the shortest path from each bus stop to the a destination (A* Alg)
  bfscore            ; for calculating the shortest path from each bus stop to the a destination (A* Alg)
  bgscore            ; for calculating the shortest path from each bus stop to the a destination (A* Alg)
  bus-path          ; best path from an intersection to the horizontal destination (list of intersection 'who's)
  evacuee_count     ; the number of agents that are evacuated at an intersection, if there is a destination in it
  vuln_count        ; the number of vulnerable agents arrived at an intersection, if there is a destination in it
]


cars-own [       ; the variables that cars own
  current_int    ; current/previous intersection of an agent, 0 if none
  moving?        ; true if the agent is moving, false if not (e.g., turning at intersection)
  arrived?       ; true if an agent is evacuated, either in a destination or outside of the destination
  next_int       ; the next intersection an agent is heading towards
  destination    ; 'who' of the intersection that the agent is heading to (its destination)
  speed          ; speed of the agent, measured in patches per tick
  c-path         ; list of intersection 'who's that represent the path to the destination of an agent
  decision       ; the agents decision code: 2
  car_ahead      ; the car that is immediately ahead of the agent
  space_hw       ; the space headway between the agent and 'car_ahead'
  speed_diff     ; the speed difference between the agent and 'car_ahead'
  acc            ; acceleration of the car agent
  road_on        ; the link that the car is travelling on
  vulnerable?    ; true if the agent is vulnerable (speed < 0.1 m/s), false if not
  collected?     ; true if the agent is collected for evacuation from the responders, false if not
  income         ;average monthly income (after taxes) in the city of Larissa
]

buses-own [
  current_int    ; current/previous intersection of an agent, 0 if none
  moving?        ; true if the agent is moving, false if not (e.g., turning at intersection)
  arrived?       ; true if an agent is evacuated, either in a destination or outside of the destination
  next_int       ; the next intersection an agent is heading towards
  destination        ; 'who' of the intersection that the agent is heading to (its destination)
  speed          ; speed of the agent, measured in patches per tick
  b-path           ; list of intersection 'who's that represent the path to the destination of an agent
  decision       ; the agents decision code: 1
  car_ahead      ; the car that is immediately ahead of the agent
  space_hw       ; the space headway between the agent and 'car_ahead'
  speed_diff     ; the speed difference between the agent and 'car_ahead'
  acc            ; acceleration of the car agent
  road_on        ; the link that the car is travelling on


  is-full?       ; true is the capacity of evacuees is exceeded
  vulnerable?    ; true if the agent is vulnerable (speed < 0.1 m/s), false if not
  collected?     ; true if the agent is collected for evacuation from the responders, false if not
  income         ;average monthly income (after taxes) in the city of Larissa

]


globals [        ; global variables
  ev_times       ; list of evacuation times (in mins) for all agents referenced from the evacuation signal
                 ; later to be used to look into the distribution of the evacuation times
  mouse-was-down?; event-handler variable to capture mouse clicks accurately
  road_network   ; contains the road network gis information
  bus_network    ; contains the bus network gis information
  population_distribution
                 ; contains population distribution gis information
  d_locations
                 ; contains destination locations gis information

  population_origins
                 ; contains travellers origins' locations gis information
  flooded_area   ; contains flooded area gis information


  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;; CONVERSION RATIOS ;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  patch_to_meter ; patch to meter conversion ratio
  fd_to_mps     ; fd (patch/tick) to meter per second
  fd_to_kmph      ; fd (patch/tick) to kilometers per hour
  tick_to_sec    ; ticks to seconds - usually 1

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;;; TRANSFORMATIONS ;;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  min_lon        ; minimum longitude that is associated with min_xcor
  min_lat        ; minimum latitude that is associated with min_ycor

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;; TRAFFIC NETWORK ASSESSMENT ;;;;;
  ;;;;;;;;; AntifragiCity ;;;;;;;;;;;;;

  speed_rec_list  ; list of speeds recorded by each pedestrian / car to identify maximum
  max_speedA      ; maximum speed observed for each pedestrian / car
  max_entropy     ; maximum speed information entropy Cmax = sum ln(max speed) of each vehicle
  curr_entropy
  vulnerables_ETA

]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; HELPER FUNCTIONS ;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; returns truen if the moouse was clicked
to-report mouse-clicked?
  report (mouse-was-down? = true and not mouse-down?)
end

; returns a list of intersections for which the shortest path to the closest destination should be calculated
to-report find-origins
  let origins []
  ask residents with [decision = 2] [
    ; add the closest intersection to each agent at the start of the simulation to the origins
    ; there is no need to calculate the shortest path for the rest of the intersections
    set origins lput min-one-of intersections [ distance myself ] origins
  ]
  ask residents with [decision = 1] [
    ; add the closest intersection to each agent at the start of the simulation to the origins
    ; there is no need to calculate the shortest path for the rest of the intersections
    set origins lput min-one-of bus_stops [ distance myself ] origins
  ]
  set origins remove-duplicates origins
  report origins
end

; generates a randomly drawn number from Rayleigh dist. with the given sigma
to-report rayleigh-random [sigma]
  report (sqrt((- ln(1 - random-float 1 ))*(2 *(sigma ^ 2))))
end

; TURTLE FUNCTION: sets random decision as to the mode (bus/car) for the travel based on the percentages entered by the user
to make-decision


    let rnd random-float 100
    ifelse (rnd < Prob_Bus ) [  ; decision to take the bus
      set decision 1
      set miltime 0
    ]
    [
      set decision 2  ; decision to take the car
      set miltime 0
    ]

  if Flood = true and Regulation = 3 [
      set Prob_Bus 0.60
      set Prob_Car 0.40
      ifelse (random-float 100 < Prob_Car ) [  ; decision to take the car
      set decision 2
      set miltime 0
    ]
    [
      set decision 1  ; decision to take the bus
      set miltime 0
     ]
    ]

end

; finds the shortest path from and intersection (source) to a destination (one of gls) with A* algorithm
; gl is only used as a heuristic for the algorithm, the closest destination in a network is not necessarily the closest in euclidean distance
to-report Astar-car [ source gl gls ]
  let rchd? false    ; true if the algorithm has found a destination
  let dstn nobody       ; the destinaton or the closest intersection
  let closedset []      ; equivalent to closed set in A* alg
  let openset []        ; equivalent to open set in A* alg
  ask intersections [   ; initialize "previous", which later will be used to reconstruct the shortest path for each intersection
    set previous -1
  ]
  set openset lput [who] of source openset  ; start the open set with the source intersection
  ask source [                              ; initialize g and f score for the source intersection
    set gscore 0
    set fscore (gscore + distance gl)
  ]
  while [ not empty? openset and (not rchd?)] [ ; while a destination hasn't been found, look for one
    let current Astar-smallest-car openset          ; pick the most promissing intersection from the open set
    if member? current  [who] of gls [          ; if it is one of the candid destinations, we're done
      set dstn intersection current             ; set the destination
      set rchd? true                            ; and toggle the flag so we don't look for a destination anymore and move on to the recosntructing the path
    ]
    set openset remove current openset          ; update the open and closed set
    set closedset lput current closedset
    ask intersection current [                  ; explore the neighbors of the current intersection
      ask out-road-neighbors [
        let tent_gscore [gscore] of myself + [link-length] of (road [who] of myself who)   ; update f and gscore tentatively
        let tent_fscore tent_gscore + distance gl
        if ( member? who closedset and ( tent_fscore >= fscore ) ) [stop]                  ; if not improved, stop
        if ( not member? who closedset or ( tent_fscore >= fscore )) [                     ; if the score improved, continue updating
          set previous current
          set gscore tent_gscore
          set fscore tent_fscore
          if not member? who openset [
            set openset lput who openset
          ]
        ]
      ]
    ]
  ]
  let route []                                    ; reconstruct the path to destination
  ifelse dstn != nobody [                         ; if there was a path
    while [ [previous] of dstn != -1 ] [          ; use "previous" to recosntruct untill "previous" is -1
      set route fput [who] of dstn route
      set dstn intersection ([previous] of dstn)
    ]
  ]
  [
    set route []                                  ; if there was no path, return an empty list
  ]
  report route
end

to-report Astar-bus [ source gl gls ]
  let rchd? false       ; true if the algorithm has found a destination
  let dstn nobody       ; the destinaton or the closest destination
  let closedset []      ; equivalent to closed set in A* alg
  let openset []        ; equivalent to open set in A* alg
  ask bus_stops [   ; initialize "previous", which later will be used to reconstruct the shortest path for each intersection
    set bprevious -1
  ]
  set openset lput [who] of source openset  ; start the open set with the source intersection
  ask source [                              ; initialize g and f score for the source intersection
    set bgscore 0
    set bfscore (bgscore + distance gl)
  ]
  while [ not empty? openset and (not rchd?)] [ ; while a destination hasn't been found, look for one
    let current Astar-smallest-bus openset          ; pick the most promissing intersection from the open set
    if member? current  [who] of gls [          ; if it is one of the candid destinations, we're done
      set dstn bus_stop current             ; set the destination
      set rchd? true                            ; and toggle the flag so we don't look for a destination anymore and move on to the recosntructing the path
    ]
    set openset remove current openset          ; update the open and closed set
    set closedset lput current closedset
    ask bus_stop current [                  ; explore the neighbors of the current intersection
      ask out-bus_lane-neighbors [
        let tent_bgscore [bgscore] of myself + [link-length] of (bus_lane [who] of myself who)   ; update f and gscore tentatively
        let tent_bfscore tent_bgscore + distance gl
        if ( member? who closedset and ( tent_bfscore >= bfscore ) ) [stop]                  ; if not improved, stop
        if ( not member? who closedset or ( tent_bfscore >= bfscore )) [                     ; if the score improved, continue updating
          set bprevious current
          set bgscore tent_bgscore
          set bfscore tent_bfscore
          if not member? who openset [
            set openset lput who openset
          ]
        ]
      ]
    ]
  ]
  let route []                                    ; reconstruct the path to destination
  ifelse dstn != nobody [                         ; if there was a path
    while [ [bprevious] of dstn != -1 ] [          ; use "previous" to recosntruct untill "previous" is -1
      set route fput [who] of dstn route
      set dstn bus_stop ([bprevious] of dstn)
    ]
  ]
  [
    set route []                                  ; if there was no path, return an empty list
  ]
  report route

end

; returns the who of an intersection in who_list with the lowest fscore
to-report Astar-smallest-car [ who_list ]
 let min_who 0
  let min_fscr 100000000
  foreach who_list [ [?1] ->
    let fscr [fscore] of intersection ?1
    if fscr < min_fscr [
      set min_fscr fscr
      set min_who ?1
    ]
  ]
  report min_who
end

to-report Astar-smallest-bus [ who_list ]
  let min_who 0
  let min_fscr 100000000
  foreach who_list [ [?1] ->
    let bfscr [bfscore] of bus_stop ?1
    if bfscr < min_fscr [
      set min_fscr bfscr
      set min_who ?1
    ]
  ]
  report min_who
end

; TURTLE FUNCTION: calculates the speed of the car based on general motors car-following model
;                  it incorporates the speed of the leading car as well as the space headway
to move-gm
  set car_ahead (turtle-set buses cars) in-cone (45 / patch_to_meter) 20                     ; get the cars ahead (almost half a block) and in field of view of 20 degrees
  set car_ahead car_ahead with [self != myself]                                              ; that are not myself
  set car_ahead car_ahead with [not arrived?]                                              ; that have not made it to the destination yet (no congestion at the destination)
  set car_ahead car_ahead with [moving?]                                                     ; that are moving
  set car_ahead car_ahead with [abs(subtract-headings heading [heading] of myself) < 160]    ; with relatively the same general heading as mine (not going the opposite direction)
  set car_ahead car_ahead with [distance myself > 0.0001]                                    ; not exteremely close to myself
  set car_ahead min-one-of car_ahead [distance myself]                                       ; and the closest car ahead
  ifelse is-turtle? car_ahead [                                                              ; if there IS a car ahead:
    set space_hw distance car_ahead                                                          ; the space headway with the leading car
    set speed_diff [speed] of car_ahead - speed                                              ; the speed difference with the leadning car
    ifelse space_hw < (1.8 / patch_to_meter) [set speed 0]                                      ; if the leading car is less than ~6ft away, stop
    [                                                                                        ; otherwise, find the acceleration based on the general motors car-following model
      set acc (alpha / fd_to_kmph * 5280 / patch_to_meter) * ((speed) ^ 0) / ((space_hw) ^ 2) * speed_diff
                                                                                             ; converting mi2/hr to patch2/tick = converting mph*mi to fd*patch
                                                                                             ; m = speed componnent = 0 / l = space headway component = 2
      set speed speed + acc                                                                  ; update the speed
    ]
    if speed > (space_hw - (6 / patch_to_meter)) [                                            ; if the current speed will put the car less than 6ft away from the leading car in the next second,
      set speed min list (space_hw - (6 / patch_to_meter)) [speed] of car_ahead               ; reduce the speed in a way to not get closer to the leading car
    ]
    if speed > (max_speed / fd_to_kmph) [set speed (max_speed / fd_to_kmph)]                   ; cap the speed to max speed if larger
    if speed < 0 [set speed 0]                                                               ; no negative speed
  ]
  [                                                                                          ; if ther IS NOT a car ahead:
    if speed < (max_speed / fd_to_kmph) [set speed speed + (acceleration / fd_to_mps * tick_to_sec)]
                                                                                             ; accelerate to get to the speed limit
    if speed > max_speed / fd_to_kmph [set speed max_speed / fd_to_kmph]                       ; cap the speed to max speed if larger
  ]

  if speed > distance next_int [set speed distance next_int]                                 ; avoid jumping over the next intersection the car is heading to
end

; TURTLE FUNCTION: marks an agent as arrived
to mark-arrived
  if not arrived? [                              ; if the agents has not arrived, mark it as arrived and set proper characteristics
    set color green
    set moving? false
    set arrived? true
    set ev_times lput ( ticks * tick_to_sec / 60 ) ev_times      ; add the arrival time (in minutes) to ev_times list
    ask current_int [set evacuee_count evacuee_count + 1]        ; increment the evacuee_count of the destination the agent arrived to
    if vulnerable? = true [
      ask current_int [set vuln_count vuln_count + 1 ]
      ]
  ]

end

; returns true if the general direction (north, east, south, west) and the heading (0 <= h < 360) are alligned
; used for removing one-way roads
to-report is-heading-right? [link_heading direction]
  if direction = "north" [ if abs(subtract-headings 0 link_heading) <= 90 [report true]]
  if direction = "east" [ if abs(subtract-headings 90 link_heading) <= 90 [report true]]
  if direction = "south" [ if abs(subtract-headings 180 link_heading) <= 90 [report true]]
  if direction = "west" [ if abs(subtract-headings 270 link_heading) <= 90 [report true]]
  report false
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; SETUP INITIAL PARAMETERS ;:;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; this function sets some initial value for an initial try to run the model
; if the user decides not to tweak any of the inputs
to setup-init-val
  set Prob_Bus 30                 ; 30% of the agents use the bus
  set Prob_Car 70                 ; 70% of the agents evacuate horizontally with their car
  set Ped_Speed 1.2               ; the mean of the normal dist. that the walking speed of the agents are drawn from is set to 1.2 m/s
  set Ped_Sigma 0.05              ; the standard deviation of the normal dist. that the walking speed of the agents are drawn from is set to 0.20 m/s
  set max_speed 50                ; maximum driving speed is set to 50 km/h
  set acceleration 1.5            ; acceleration of the vehicles is set to 1.5 m/s2
  set deceleration 7.62           ; deceleration of the vehicles is set to 7.62 m/s2
  set alpha 0.14                  ; alpha parameter (sensitivity coefficient) of the car-following model is preset to 0.14 km2/hr

  set Rtau1 10
  set Rtau2 10
  set Rsig1 1.65                  ; the scale factor parameter of the Rayleigh distribution for all decision categories is set to 1.65
  set Rsig2 1.65                  ; meaning that 99% of the agents evacuate within 5 minutes after the minimum milling time (between 10 to 15 mins in this case)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;; READ GIS FILES ;:;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; read the gis files that are used to populate the model:
;   1. road_network that contains the transportation network data
;   2. destination_locations that contains the location of the horizontal and vertical destinations
;   3. population_distribution that contains the coordinates of the agents immediately before the evacuation
to read-gis-files
  gis:load-coordinate-system "road_network/road_network.prj"                                              ; load the projection system - WGS84 / UTM (METER) for your specific area
  set d_locations gis:load-dataset "origins-destinations/destinations.shp"                                ; read travellers destination locations
  set road_network gis:load-dataset "road_network/road_network.shp"                                       ; read road network
  set bus_network gis:load-dataset "road_network/bus_network.shp"                                         ; read bus network
  set population_origins gis:load-dataset "origins-destinations/origins.shp"                              ; read travellers origin areas
  set flooded_area gis:load-dataset "flood/flood.shp"                                                     ; read the extent of the Daniel Flood (2023)
  let world_envelope  (gis:envelope-union-of (gis:envelope-of road_network)                               ; set the real world bounding box the union of all the read shapefiles
                                             (gis:envelope-of bus_network)
                                             (gis:envelope-of d_locations)
                                             (gis:envelope-of population_origins)
                                             (gis:envelope-of flooded_area))

  let netlogo_envelope (list (min-pxcor + 1) (max-pxcor - 1) (min-pycor + 1) (max-pycor - 1))             ; read the size of netlogo world
  gis:set-transformation (world_envelope) (netlogo_envelope)                                              ; make the transformation from real world to netlogo world
  let world_width item 1 world_envelope - item 0 world_envelope                                           ; real world width in meters
  let world_height item 3 world_envelope - item 2 world_envelope                                          ; real world height in meters
  let world_ratio world_height / world_width                                                              ; real world height to width ratio
  let netlogo_width (max-pxcor - 1) - ((min-pxcor + 1))                                                   ; netlogo width in patches (minus 1 patch padding from each side)
  let netlogo_height (max-pycor - 1) - ((min-pycor + 1))                                                  ; netlogo height in patches (minus 1 patch padding from each side)
  let netlogo_ratio netlogo_height / netlogo_width                                                        ; netlogo height to width ratio
  ; calculating the conversion ratios
  set patch_to_meter max (list (world_width / netlogo_width) (world_height / netlogo_height))             ; patch_to_meter conversion multiplier
  set tick_to_sec 1.0                                                                                     ; tick_to_sec ratio is set to 1.0 (preferred)
  set fd_to_mps patch_to_meter / tick_to_sec                                                              ; patch/tick to ft/s speed conversion multipler
  set fd_to_kmph  fd_to_mps * 3.6            ; 1m/s = 3.6 km/h                                            ; patch/tick to mph speed conversion multiplier
  ; to calculate the minimum longitude and latitude of the world associated with min_xcor and min_ycor
  ; we need to check and see how the world envelope fits into that of netlogo's. This is why the "_ratio"s need to be compared againsts eachother
  ; this is basically the missing "get-transformation" premitive in netlogo's GIS extension
  ifelse world_ratio < netlogo_ratio [
    set min_lon item 0 world_envelope - patch_to_meter
    set min_lat item 2 world_envelope - ((netlogo_ratio - world_ratio) / netlogo_ratio / 2) * netlogo_height * patch_to_meter - patch_to_meter
  ][
    set min_lon item 0 world_envelope - ((world_ratio - netlogo_ratio) / world_ratio / 2) * netlogo_width * patch_to_meter - patch_to_meter
    set min_lat item 2 world_envelope - patch_to_meter
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;; LOAD NETWORK ;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; loads the transportation network, consisting of roads and intersections from "road_network" and "bus_network" gis files
; that are places under "road_network" directroy. Note the "direction" attribute associated with each road
; which can either be "two-way" "north" "east" "south" or "west".
to load-network
  ; first remove the intersections and roads, if any
  ask intersections [die]
  ask roads [die]
  ask bus_stops [die]
  ask bus_lanes [die]
  ; start loading the road network
  foreach gis:feature-list-of road_network [ i ->                                      ; iterating through features to create intersections and roads
    let direction gis:property-value i "DIRECTION"                                     ; get the direction of the link to make either a one- or two-way road
    foreach gis:vertex-lists-of i [ j ->                                               ; iterating through the list of vertex lists (usually lengths of 1) of each feature
      let prev -1                                                                      ; previous vertex indicator, -1 if None
      foreach j [ k ->                                                                 ; iterating through the vertexes
        if length ( gis:location-of k ) = 2 [                                          ; check if the vertex is valid with both x and y values
          let x item 0 gis:location-of k                                               ; get x and y values for the intersection
          let y item 1 gis:location-of k
          let curr 0
          ifelse any? intersections with [xcor = x and ycor = y][                      ; check if there is an intersection here, if not, make one, and if it is, use it
            set curr [who] of one-of intersections with [xcor = x and ycor = y]
          ][
            create-intersections 1 [
              set xcor x
              set ycor y
              set destination? false
              set size 0.1
              set shape "square"
              set color white
              set curr who
            ]
          ]
          if prev != -1 and prev != curr [                                             ; if this intersection is not the starting intersection, make roads
            ifelse direction = "two-way" [                                             ; if the road is "two-way" make both directions
              ask intersection prev [create-road-to intersection curr]
              ask intersection curr [create-road-to intersection prev]
            ][                                                                         ; if not, make only the direction that matches the direction requested, see is-heading-right? helper function
              if is-heading-right? ([towards intersection curr] of intersection prev) direction [ ask intersection prev [create-road-to intersection curr]]
              if is-heading-right? ([towards intersection prev] of intersection curr) direction [ ask intersection curr [create-road-to intersection prev]]
            ]
          ]
          set prev curr
        ]
      ]
    ]
  ]
  ; assign mid-x and mid-y variables to the roads that respresent the middle point of the link
  ask roads [
    set color black
    set thickness 0.05
    set mid-x mean [xcor] of both-ends
    set mid-y mean [ycor] of both-ends
    set traffic 0
    set crowd 0
  ]

   ; start loading the bus network
  foreach gis:feature-list-of bus_network [ i ->                                       ; iterating through features to create bus stops and lanes
    let direction gis:property-value i "DIRECTION"                                     ; get the direction of the link to make either a one- or two-way route
    foreach gis:vertex-lists-of i [ j ->                                               ; iterating through the list of vertex lists (usually lengths of 1) of each feature
      let prev -1                                                                      ; previous vertex indicator, -1 if None
      foreach j [ k ->                                                                 ; iterating through the vertexes
        if length ( gis:location-of k ) = 2 [                                          ; check if the vertex is valid with both x and y values
          let x item 0 gis:location-of k                                               ; get x and y values for the intersection
          let y item 1 gis:location-of k
          let curr 0
          ifelse any? bus_stops with [xcor = x and ycor = y][                          ; check if there is a bus stop intersection here, if not, make one, and if it is, use it
            set curr [who] of one-of bus_stops with [xcor = x and ycor = y]
          ][
            create-bus_stops 1 [
              set xcor x
              set ycor y
              set destination? false
              set size 0.5
              set shape "square"
              set color green
              set curr who
            ]
          ]
          if prev != -1 and prev != curr [                                             ; if this bus stop is not the starting bus stop, make bus lanes
            ifelse direction = "two-way" [                                             ; if the bus lane is "two-way" make both directions
              ask bus_stop prev [create-bus_lane-to bus_stop curr]
              ask bus_stop curr [create-bus_lane-to bus_stop prev]
            ][                                                                         ; if not, make only the direction that matches the direction requested, see is-heading-right? helper function
              if is-heading-right? ([towards bus_stop curr] of bus_stop prev) direction [ ask bus_stop prev [create-bus_lane-to bus_stop curr]]
              if is-heading-right? ([towards bus_stop prev] of bus_stop curr) direction [ ask bus_stop curr [create-bus_lane-to bus_stop prev]]
            ]
          ]
          set prev curr
        ]
      ]
    ]
  ]
  ; assign mid-x and mid-y variables to the bus lanes that respresent the middle point of the link
  ask bus_lanes [
    set color green
    set thickness 0.15
    set mid-x mean [xcor] of both-ends
    set mid-y mean [ycor] of both-ends
    set traffic 0
    set crowd 0
  ]
  output-print "Network Loaded"
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;; LOAD DESTINATIONS ;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; loads the destinations from from "destination_locations" gis files that are under "destination_locations" directory
; note the "type" attribute associated with each destination in the gis file, which can either be "hor" or "ver"
; for horizontal and vertical destinations.
to load-destinations
  ; remove all the destinations before loading them
  ask intersections [
    set destination? false
    set destination_type "None"
    set color white
    set size 0.1
  ]
  ask bus_stops [
      set destination? false
      set destination_type "None"
      set size 0.1
  ]
  ; start loading the destinations
  foreach gis:feature-list-of d_locations [ i ->               ; iterate through the destinations
    let curr_destination_type gis:property-value i "TYPE"      ; get the type of the destination
    foreach gis:vertex-lists-of i [ j ->
      foreach j [ k ->
        if length ( gis:location-of k ) = 2 [              ; check if the vertex has both x and y
          let x item 0 gis:location-of k
          let y item 1 gis:location-of k
          ask min-one-of (turtle-set intersections bus_stops) [distancexy x y]  [
            set destination? true
            set shape "circle"
            set size 1

            st
          ]
        ]
      ]
    ]
  ]
  output-print "Destinations Loaded"
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;; LOAD POPULATION ;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; loads the evacuees from "population_distribution" gis files that are located under "population_distribution" directroy
; this gis shapefile contains the coordinates of the evacuees at the start of the evacuation
to load-origins
  ; remove any residents, cars or buses before loading the population
  ask residents [ die ]
  ask cars [die]
  ask buses [die]
  ; start loading the travellers' origins based on gis shapefile

  foreach gis:feature-list-of population_origins [ i ->           ; iterate through the points in the features
    let origin_density gis:property-value i "ID"             ; get the density of travellers
    if origin_density = 1
      [gis:create-turtles-inside-polygon i residents 120
        ask residents [
          set income random-normal 1200 200]]
    if origin_density = 2
      [gis:create-turtles-inside-polygon i residents 70
        ask residents [
          set income random-normal 1034 200]]
    if origin_density = 3
      [gis:create-turtles-inside-polygon i residents 120
        ask residents [
          set income random-normal 1300 300]]
    if origin_density = 4
      [gis:create-turtles-inside-polygon i residents 100
        ask residents [
          set income random-normal 1500 300]]
    if origin_density = 5
      [gis:create-turtles-inside-polygon i residents 50
         ask residents [
          set income random-normal 1800 200]]
    if origin_density = 6
      [gis:create-turtles-inside-polygon i residents 20
        ask residents [
          set income random-normal 2000 400]]
    if origin_density = 7
      [gis:create-turtles-inside-polygon i residents 50
        ask residents [
          set income random-normal 1800 200]]
    if origin_density = 8
      [gis:create-turtles-inside-polygon i residents 50
        ask residents [
          set income random-normal 1800 300]]
    if origin_density = 9
      [gis:create-turtles-inside-polygon i residents 30
        ask residents [
          set income random-normal 2200 200]]
    if origin_density = 10
      [gis:create-turtles-inside-polygon i residents 10
        ask residents [
          set income random-normal 1800 300]]
    if origin_density = 11
      [gis:create-turtles-inside-polygon i residents 100
        ask residents [
          set income random-normal 1100 200]]
    if origin_density = 12
      [gis:create-turtles-inside-polygon i residents 200
        ask residents [
          set income random-normal 1400 500]]
    if origin_density = 13
      [gis:create-turtles-inside-polygon i residents 300
        ask residents [
          set income random-normal 2000 500]]
    if origin_density = 14
      [gis:create-turtles-inside-polygon i residents 250
        ask residents [
          set income random-normal 2000 500]]
    if origin_density = 15
      [gis:create-turtles-inside-polygon i residents 300
        ask residents [
          set income random-normal 2000 500]]
  ]

          ask residents [                                          ; create the agent

            set color brown
            set shape "dot"
            set size 2
            set moving? false                                          ; the agents are stationary at the beginning, before they start the trip
            make-decision                                              ; sets the travel mode and destination decision
            ifelse decision = 1
             [set init_dest min-one-of bus_stops [ distance myself ] ]
             [set init_dest min-one-of intersections [ distance myself ] ]
                                                                       ; the first intersection or bus stop an agent moves toward to, to get to the transpotation network
            set speed Ped_Speed ;random-normal Ped_Speed Ped_Sigma                ; walking speed is randomly drawn from a normal distribution
            set speed speed / fd_to_mps                                ; turning m/s to patch/tick
            if speed < 0.03                                            ; if speed is too low, set it to very small non-zero value
                 [set speed 0.05]

            set arrived? false                                         ; initialized as not arrived
            set reached? false                                         ; initialized as not reached the transportation network
            set collected? false                                       ; initialized as not collected by responders

            set miltime 0
            ]



  output-print "Origins Loaded"
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;; LOAD ROUTES ;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; calcualtes routes for the intersections that need the shortest path information to a destination, not all the intersections
to load-routes
  let origins find-origins
  ask intersections with [member? self origins] [
    let goals intersections with [destination?]
    if Regulation != 1
      [set car-path Astar-car self (min-one-of goals [distance myself]) goals ]; hor-path definitely goes to a horizontal destination
    if Flood = true and Regulation = 1
      [set car-path Astar-car self (max-one-of goals [distance myself]) goals in-radius 10  ]        ;goals in-radius 10
  ]

  ask bus_stops  with [member? self origins] [
    let goals bus_stops with [destination?]
    if Regulation != 1
      [set bus-path Astar-bus self (min-one-of goals [distance myself]) goals ] ; hor-path definitely goes to a horizontal destination
    if Flood = true and Regulation = 1
      [set bus-path Astar-car self (max-one-of goals [distance myself]) goals in-radius 10  ]        ;goals in-radius 10
  ]
  output-print "Routes Calculated"
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;; LOAD 1/2 ;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; first part of loading the model, including transportation network, destinations, and tsunami data
; before breaking roads and adding vertical destinations
to load1
  ca
  ask patches [set pcolor white]
  set ev_times []
  read-gis-files
  load-network
  load-destinations
  reset-timer
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;; LOAD 2/2 ;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; second part of loading the model, including population distribution and the routes
; after breaking the roads and adding the vertical destinations
; calculating roads is based on the vertical destinations and current state of the roads
to load2
  load-origins
  load-routes
  reset-ticks
end

;######################################
;*************************************#
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;*#
;;;;;;;;;;;;;    GO    ;;;;;;;;;;;;;;*#
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;*#
;*************************************#
;######################################

to go


  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;; RESIDENTS ;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ; ask residents, if they milling time has passed, to start moving
  ask residents with [moving? = false][
    ifelse init_dest != self ;and heading = true
      [face init_dest
       set moving? true ]
      [set heading 0]
  ]
  ; ask residents that should be moving to move
  ask residents with [moving? = true][
    ifelse (distance init_dest < (speed) ) [fd distance init_dest][fd speed]
    if distance init_dest < 0.005 [   ; if close enough to the next intersection, move the agent to it
      move-to init_dest
      set moving? false
      set reached? true
      set current_int init_dest
    ]
  ]


  ; ask residets who have reached the network to hatch into a pedestrian or a car depending on their decision
  ask residents with [reached? = true][
    let spd speed                ; to pass on the spd from resident to the hatched vehicle
    let dcsn decision            ; to pass on the decision from the resident to either car or bus
    if dcsn = 1 [                ; travel to destination BY BUS
      ask current_int [          ; ask the current bus stop of the resident to hatch a bus commuter
       hatch-buses 1 [
          set size 2
          set shape "dot"
          set current_int myself ; myself = current_int of the resident
          set arrived? false   ; initialized as not evacuated, will be checked immediately after being born
          set moving? false      ; initialized as not moving, will start moving immediately after if not evacuated and not dead
          if dcsn = 1 [          ; travel by bus
            set color cyan
            set b-path [bus-path] of myself ; myself = current_int of the resident - Note that intersection hold the path infomration

            set decision 1
          ]
          st
        ]
      ]

    if Flood = true and Regulation = 2 [
       ask current_int [          ; ask the current bus stop of the resident to hatch a bus commuter
          if random 2 = 0 [
          hatch-buses 1 [
          set size 2
          set shape "dot"
          set current_int myself ; myself = current_int of the resident
          set arrived? false   ; initialized as not evacuated, will be checked immediately after being born
          set moving? false      ; initialized as not moving, will start moving immediately after if not evacuated and not dead
          if dcsn = 1 [          ; travel by bus
            set color cyan
            set b-path [bus-path] of myself ; myself = current_int of the resident - Note that intersection hold the path infomration

            set decision 1
          ]
          st
        ]
          ]
      ]
      ]
    ]
      ask buses [
        set vulnerable? false
        set income [income] of myself
        ]


    if dcsn = 2 [               ; travel to destination by CAR
       ask current_int [         ; ask the current intersection of the resident to hatch a car
        hatch-cars 1 [
          set size 2
          set current_int myself ; myself = current_int of the resident
          set arrived? false   ; initialized as not evacuated, will be checked immediately after being born
          set moving? false      ; initialized as not moving, will start moving immediately
          if dcsn = 2 [          ; travel by car
            set color orange
            set c-path [car-path] of myself ; myself = current_int of the resident
            set decision 2
          ]
          st
        ]
      ]

      if Flood = true and Regulation = 2 [
        ask current_int [         ; ask the current intersection of the resident to hatch a car
          if random 2 = 0 [
          hatch-cars 1 [
          set size 2
          set current_int myself ; myself = current_int of the resident
          set arrived? false   ; initialized as not evacuated, will be checked immediately after being born
          set moving? false      ; initialized as not moving, will start moving immediately
          if dcsn = 2 [          ; travel by car
            set color orange
            set c-path [car-path] of myself ; myself = current_int of the resident
            set decision 2
          ]
          st
        ]
        ]
      ]
    ]
    ]
      ask cars [
         set vulnerable? false
         set income [income] of myself
        ]

    die
  ]

  ask (turtle-set buses cars) [
    if income < mean [income] of (turtle-set buses cars) [
        set vulnerable? true
    ]
  ]

  ask (turtle-set residents cars buses) [
    if count (turtle-set residents cars buses) > 3000 [
      ask n-of (3000 - count (turtle-set residents cars buses)) (turtle-set residents cars) [ die ]
    ]
  ]

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;; BUS COMMUTERS ;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ; check the bus commuters if they have arrived already or still travelling
  ask buses with [arrived? = false][
    if [who] of current_int = destination or destination = -99 [mark-arrived]
  ]
  ; set up the buses that should move
  ask buses with [moving? = false and arrived? = false][
      set destination [who] of one-of other bus_stops with [destination?]
      set next_int min-one-of bus_stops [distance bus_stop [destination] of myself]      ; assign item 0 of path to bus_stop
      face next_int              ; set the heading towards the bus_stop
      set moving? true
      ifelse bus_lane ([who] of current_int) ([who] of next_int) != nobody
        [ask bus_lane ([who] of current_int) ([who] of next_int) [set traffic traffic + 1] ] ; add the traffic of the bus_lane the car will be on
        [set moving? false]
  ]
  ; move the bus that should move
  ask buses with [moving? = true][
    move-gm                 ; set the speed with general motors car-following model
    fd (2 * speed / 3)      ; move
    if (distance next_int < 0.005 ) [    ; if close enough check if arrived? if neither, get ready for the next step
      set moving? false
      ask bus_lane ([who] of current_int) ([who] of next_int)[set traffic traffic - 1] ; decrease the traffic of the road the bus was on
      set current_int next_int           ; update current intersection
      if [who] of current_int = destination [mark-arrived]
    ]
  ]


  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;;;; CARS ;;;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ; check the cars if they have evacuated already or died
  ask cars with [not arrived?][
    if [who] of current_int = destination or destination = -99 [mark-arrived]
  ]
  ; set up the cars that should move
  ask cars with [moving? = false and is-list? c-path = true and empty? c-path = false and arrived? = false][
    set next_int intersection item 0 c-path   ; assign item 0 of path to next_int
    set c-path remove-item 0 c-path           ; remove item 0 of path
    ifelse next_int != nobody
    [set heading towards next_int                             ; set the heading towards the destination
    set moving? true
    ifelse road ([who] of current_int) ([who] of next_int) != nobody
      [ask road ([who] of current_int) ([who] of next_int) [set traffic traffic + 1]  ] ; add the traffic of the road the car will be on
      [set moving? false ]
    ]
    [
     set destination [who] of one-of intersections with [destination?]
     set next_int intersection destination; min-one-of intersections [distance [intersection destination] of myself]
     set heading towards next_int                             ; set the heading towards the destination
     set moving? true
     ask road ([who] of current_int) ([who] of next_int)[set traffic traffic + 1]
    ]
  ]
    ask cars with [moving? = false and arrived? = false][
    set current_int one-of intersections with [destination? = false]
    set destination [who] of one-of other intersections with [destination?]
    set next_int min-one-of intersections [distance intersection [destination] of myself]
    face next_int                             ; set the heading towards the destination
    set moving? true
    ifelse road ([who] of current_int) ([who] of next_int) != nobody
    [ask road ([who] of current_int) ([who] of next_int) [set traffic traffic + 1] ]
    [set moving? false]
  ]

  ; move the cars that should move
  ask cars with [moving?][
    move-gm                 ; set the speed with general motors car-following model
    fd speed                ; move
    if (distance next_int < 0.05 ) [    ; if close enough check if arrived? if neither, get ready for the next step
      set moving? false
      ask road ([who] of current_int) ([who] of next_int)[set traffic traffic - 1] ; decrease the traffic of the road the cars was on
      set current_int next_int           ; update current intersection
      if [who] of current_int = destination [mark-arrived]
    ]
  ]

  ask cars with [arrived?] [
  set current_int one-of intersections with [destination? = false]
  set arrived? false
  ]

   update-travellers

  if Flood = true
      [to-flood]

  tick

if ticks > 3600
  [stop]

end

to update-travellers

 foreach gis:feature-list-of population_origins [ i ->                                ; iterate through the points in the features
    gis:create-turtles-inside-polygon i residents (count buses with [arrived? = true] / 14)]
    ask residents [                                          ; create the agent

            set color brown
            set shape "dot"
            set size 2
            set moving? false                                          ; the agents are stationary at the beginning, before they start the trip
            make-decision                                              ; sets the travel mode and destination decision
            ifelse decision = 1
             [set init_dest min-one-of bus_stops [ distance myself ] ]
             [set init_dest min-one-of intersections [ distance myself ] ]
                                                                       ; the first intersection or bus stop an agent moves toward to, to get to the transpotation network
            set speed Ped_Speed ;random-normal Ped_Speed Ped_Sigma                ; walking speed is randomly drawn from a normal distribution
            set speed speed / fd_to_mps                                ; turning m/s to patch/tick
            if speed < 0.03                                            ; if speed is too low, set it to very small non-zero value
                 [set speed 0.05]

            set arrived? false                                         ; initialized as not arrived
            set reached? false                                         ; initialized as not reached the transportation network
            set collected? false                                       ; initialized as not collected by responders

            set miltime 0
            ]

end

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;; NETWORK ASSESSMENT ;;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to-report per_arrived
 ifelse any? (turtle-set buses cars)
  [report sum [evacuee_count] of (intersections) + sum [evacuee_count] of (bus_stops) / (count residents + count buses + count cars) * 100]
  [report "n/a"]

end

to-report vulnerable_arr_rate
  ifelse any? buses with [vulnerable? = true] or any? cars with [vulnerable? = true]
    [report max [sum [vuln_count] of (turtle-set intersections bus_stops)] of (turtle-set intersections bus_stops)
            /(count buses with [vulnerable? = true] + count cars with [vulnerable? = true]) * 100]
   [report "n/a"]

end

to-report throughput
                     ; mobility throughput M(t) measures effective service delivery : cars that move / total cars per tick
 ifelse any? (turtle-set cars buses)
   [report (count (turtle-set cars buses) with [moving?] / count (turtle-set cars buses))]
   [report "n/a"]
end

to-report stress
                     ; stress S(t) captures congestion induced degradation - difference in speeds between average and current state: % change from ref_traffic
 ifelse any? (turtle-set cars buses)
  [report 0.5 * ((mean [speed] of buses - max_speed) / max_speed) +
    0.5 * ((mean [speed] of cars - max_speed) / max_speed)  * 100]
  [report "n/a"]
end

to-report redundancy
                     ; redundancy R(t) provides alternative pathways: dormant links / active links (pre-event)
  ifelse any? intersections with [any? (turtle-set cars buses) with [moving?] in-radius 2]
     [let dormant_links count intersections with [not any? (turtle-set cars) with [moving?] in-radius 2]
      let active_links count intersections with [any? (turtle-set cars) with [moving?] in-radius 2]
      report 1 - (dormant_links / active_links) / (324 / 292)   ]                   ;reference value from baseline evacuation scenario NO
     [report "n/a"]
end

to-report entropy
                     ; information entropy C(t) quantifies flow distribution diversity: C= sum ln(speed) and overall entropy normalized: C / Cmax
 ifelse any? (turtle-set buses cars)
  [report -1 * (ln (mean [speed] of (turtle-set buses cars))) / (ln (mean [max_speed] of (turtle-set buses cars)))]
  [report "n/a"]
end

to-report theil-t
                    ; stratified Theil-T of accessibility minutes across income or neighbourhood groups
   ifelse any? (turtle-set buses cars) with [arrived? = true]
     [report sum [(mean [income] of (turtle-set buses cars) with [arrived? = true]) / (mean [income] of (turtle-set buses cars)) *
      (ln (mean [income] of (turtle-set buses cars) with [arrived? = true]) / (mean [income] of (turtle-set buses cars)))] of (turtle-set buses cars)]
     [report "n/a"]
end


  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;;;; DISRUPTIVE EVENT ;;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to to-flood

  ask patches [ set flooded? false ]

    foreach gis:feature-list-of flooded_area [
       x ->
       ask patches gis:intersecting x [
       set pcolor 107
       set flooded? true
    ]
  ]

  ask (turtle-set residents cars buses) [
    if [flooded? = true] of patch-here [
      set speed (speed * ((100 - flood_intensity) / 100))
    ]
  ]

end

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;;; RESPONSE PROCESSES ;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@#$#@#$#@
GRAPHICS-WINDOW
228
10
729
723
-1
-1
3.5025
1
10
1
1
1
0
0
0
1
-70
70
-100
100
1
1
1
ticks
30.0

PLOT
872
135
1296
293
Percentage Arrived
Min
%
0.0
10.0
0.0
5.0
true
true
"" ""
PENS
"Arrived to Dest" 1.0 0 -10899396 true "" "plotxy (ticks / 60) (sum [evacuee_count] of (turtle-set intersections bus_stops) / (count residents + count buses + count cars) * 100)"
"Cars" 1.0 0 -13345367 true "" "plotxy (ticks / 60) (sum [evacuee_count] of intersections / (count residents + count buses + count cars) * 100)"
"Buses" 1.0 0 -14835848 true "" "plotxy (ticks / 60) (sum [evacuee_count] of bus_stops / (count residents + count buses + count cars) * 100)"

BUTTON
88
14
217
47
GO
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
4
132
262
161
Residents' Decision Making Probabalities(%):
11
0.0
1

INPUTBOX
11
151
112
211
Prob_Bus
30.0
1
0
Number

MONITOR
750
14
832
59
Time (min)
ticks / 60
1
1
11

BUTTON
7
52
103
85
Read (1/2)
load1\noutput-print \"READ (1/2) DONE!\"\nbeep
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
8
431
58
491
Rtau1
10.0
1
0
Number

INPUTBOX
58
431
108
491
Rsig1
1.65
1
0
Number

TEXTBOX
10
415
210
443
Travel Mode Decsion Making Times:
11
0.0
1

TEXTBOX
22
216
71
244
On foot: (m/s)
11
0.0
1

INPUTBOX
70
218
140
278
Ped_Speed
1.2
1
0
Number

INPUTBOX
148
218
219
278
Ped_Sigma
0.05
1
0
Number

MONITOR
850
14
948
59
Arrived
sum [evacuee_count] of (intersections) + sum [evacuee_count] of (bus_stops)
0
1
11

MONITOR
954
68
1112
113
Vulnerable Arrived (%)
vulnerable_arr_rate
2
1
11

BUTTON
116
52
217
85
Read (2/2)
load2\noutput-print \"READ (2/2) DONE!\"\nbeep
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
953
14
1040
59
Travelling
count (turtle-set cars buses) with [moving?]
17
1
11

INPUTBOX
120
151
220
211
Prob_Car
70.0
1
0
Number

INPUTBOX
114
431
164
491
Rtau2
10.0
1
0
Number

INPUTBOX
164
431
214
491
Rsig2
1.65
1
0
Number

INPUTBOX
70
282
141
342
max_speed
50.0
1
0
Number

TEXTBOX
17
282
57
310
by car:\n(km/h)
11
0.0
1

INPUTBOX
3
344
76
404
acceleration
1.5
1
0
Number

INPUTBOX
80
344
155
404
deceleration
7.62
1
0
Number

INPUTBOX
158
345
223
405
alpha
0.14
1
0
Number

BUTTON
7
14
62
47
Initialize
setup-init-val
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
872
468
1295
689
Arrival Time Histogram
Minutes (after the initiation)
#
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Histogram" 1.0 1 -16777216 true "set-plot-x-range 0 60\nset-plot-y-range 0 count turtles with [ color = green ]\nset-histogram-num-bars 60\nset-plot-pen-mode 1 ; bar mode" "histogram ev_times"
"Mean" 1.0 0 -10899396 true "set-plot-pen-mode 0 ; line mode" "plot-pen-reset\nplot-pen-up\nplotxy mean ev_times 0\nplot-pen-down\nplotxy mean ev_times plot-y-max"
"Median" 1.0 0 -2674135 true "set-plot-pen-mode 0 ; line mode" "plot-pen-reset\nplot-pen-up\nplotxy median ev_times 0\nplot-pen-down\nplotxy median ev_times plot-y-max"

MONITOR
817
68
947
113
Total Arrived (%)
per_arrived
2
1
11

PLOT
872
298
1297
461
Vulnerable Population Arrived
Min
%
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Arrived" 1.0 0 -10899396 true "" "plotxy (ticks / 60) vulnerable_arr_rate * 100"
"Not Arrived" 1.0 0 -2674135 true "" "plotxy (ticks / 60) (per_arrived - vulnerable_arr_rate) * 100"

CHOOSER
14
580
128
625
Regulation
Regulation
"NO" "1" "2" "3"
2

TEXTBOX
17
561
235
595
Responses during flood:
11
0.0
1

MONITOR
745
165
854
210
Throughput M
throughput
3
1
11

TEXTBOX
745
138
895
156
AntifragiCity KPIs
14
0.0
1

MONITOR
745
218
854
263
Efficiency S (%)
stress
3
1
11

MONITOR
745
269
854
314
Redundancy R (%)
redundancy
3
1
11

MONITOR
745
320
854
365
Entropy C
entropy
3
1
11

SWITCH
10
516
100
549
Flood
Flood
0
1
-1000

SLIDER
106
516
221
549
flood_intensity
flood_intensity
10
100
10.0
10
1
%
HORIZONTAL

MONITOR
745
371
854
416
Theil-T Q
theil-t
3
1
11

@#$#@#$#@
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="No Dis TEST" repetitions="1" runMetricsEveryStep="true">
    <setup>load1
load2</setup>
    <go>go</go>
    <timeLimit steps="1200"/>
    <metric>count cars</metric>
    <metric>per_arrived</metric>
    <metric>vulnerable_arr_rate</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>theil-t</metric>
    <enumeratedValueSet variable="max_speed">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.14"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rtau1">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rtau2">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ped_Speed">
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Flood">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Prob_Car">
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rsig1">
      <value value="1.65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Prob_Bus">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rsig2">
      <value value="1.65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="7.62"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ped_Sigma">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="flood_intensity">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Regulation">
      <value value="&quot;NO&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Flood Reg 2 (all)" repetitions="9" runMetricsEveryStep="true">
    <setup>load1
load2</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count cars</metric>
    <metric>count buses</metric>
    <metric>per_arrived</metric>
    <metric>vulnerable_arr_rate</metric>
    <metric>throughput</metric>
    <metric>stress</metric>
    <metric>redundancy</metric>
    <metric>entropy</metric>
    <metric>theil-t</metric>
    <enumeratedValueSet variable="max_speed">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.14"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rtau1">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rtau2">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ped_Speed">
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Flood">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Prob_Car">
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rsig1">
      <value value="1.65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Prob_Bus">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rsig2">
      <value value="1.65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="7.62"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ped_Sigma">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="flood_intensity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Regulation">
      <value value="&quot;2&quot;"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
