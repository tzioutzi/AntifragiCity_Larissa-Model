# Larissa Flood-Resilience Mobility DSS
## Overview
The Larissa Model is an agent-based Decision Support System pilot designed to study and optimise household and resource-seeking mobility in Larissa, Greece, under flood-driven infrastructure disruption. It is one of three primary case studies (alongside Thessaloniki/AHEPA and Bratislava) developed within the AntifragiCity project as the empirical workhorse of Deliverable D3.4 — Mobility Triage Analysis DSS .
The model serves three integrated purposes:
Capture the multimodal network of Larissa — a directed road and bus network georeferenced from OpenStreetMap with QGIS 3.40, modelled as interconnected stationary agents (intersections and bus stops) joined by directed links .
Integrate socioeconomic and land-use data — static patches carry population density and the distribution of socioeconomic profiles, while the georeferenced locations of commercial stores and public services are integrated as static agents acting as trip attractors .
Quantify flood-driven household-level impacts on the routing logic — by integrating flood severity with the routing rules, the model identifies specific resource access barriers that emerge during flood events . The flood severity is a user-defined parameter while the flood-prone area is mapped from recent historical flood records .
Unlike the other pilots, Larissa's scope is household and resource-seeking trips under flood stress (in contrast to AHEPA's patient-access and Bratislava's river-crossing commute) , making it the DSS's most operationally-stressed case study.
________________________________________
## Key Features
🌊 Hydrological-Hazard-Aware Routing
The flood-prone area is mapped from historical flood records and exposed to the routing rules as a dynamic topology .
Severity modulates the reachable graph per tick, allowing stable inner-city corridors to retain flow while low-lying districts surrounding the riverbanks lose their routes .

🚶 Modal-Flexible Agents
Pedestrians select routes to their destinations based on the distance from their origin and prevailing preferences . They may either walk to their destination or transition into car passengers or bus commuters, navigating through their selected network to reach their destination through the shortest path .
Cars and buses are dynamic autonomous agents traversing their own modal network .
Vulnerability is propagated from the patch-level income profile and attached to the agent .

🏪 Trip-Attractor Layer
Commercial stores and public services are integrated as static agents that attract daily commuter inflows and resource-seeking trips from households across the city .
Together with the multimodal network this forms a complete mobility underlay that supports both commute and emergency-resource access simulations .

📊 Configurable Parameters & Scenarios
Parameter	Description
Modal share	Distribution among pedestrians, cars, buses 

Pedestrian speed	User-defined walking speed 

Car speed	User-defined car speed 

Traffic flow metrics	Acceleration / deceleration constraints 

Flood severity	User-defined inundation parameter 

Flood-prone area	Mapped from historical records 

Response selector	Do-nothing / R1 / R2 / R3 

🎯 Response Strategies
Three traffic-regulation strategies are available for investigation:
R1 — Alternative destinations in strict perimeter: R1 asks the population to determine alternative destinations within a strict perimeter from their origin point, simulating a polycentric urban structure and restricting agent movement to localized hubs to mitigate the risk of congestion on primary corridors .
R2 — Remote-work reduction of automobile demand: R2 simulates the application of administrative recommendations aimed at reducing travel and promoting remote work. It is assumed that 50% of the population are not using any automobile transport modes for work-related or resource-seeking activities, effectively dampening the immediate demand surge on the transportation network during crisis intervals .
R3 — Bus-lane prioritization: R3 focuses on modal shift towards the bus network, keeping the same routes but increasing bus capacity. It simulates the prioritization of public transit corridors, whereby designated lanes remain operational even when surrounding road segments are compromised by floodwaters .

📈 Built-In KPI Dashboard
The model tracks the KPIs defined in Deliverable D2.3 
Throughput (M) — completed trip ends (general and vulnerable separately) .
Efficiency (S) — system performance under stress .
Redundancy (R) — availability of alternative pathways .
Entropy (Q) — satisfaction/psychological stress level .
Theil-T — socioeconomic inequity measure .
Plots monitor the spatiotemporal evolution of the different serviceability aspects ().
________________________________________
## Empirical Foundation
The model's spatial structure is grounded in real-world geographic data:
Roads and bus lines are extracted from OpenStreetMap and processed in QGIS 3.40 for maximum accuracy .
Flood-prone areas are mapped from historical flood records (reference 53) .
Population density and socioeconomic profiles are spatially distributed and used to determine traveller origins, simulate modal selection, and classify vulnerable population groups .
________________________________________
## Demo Pilots in Context
Dimension	Larissa
Mobility function examined	Household and resource-seeking trips under flood stress 

Modes in the model	Pedestrians, cars, buses 

Disruption typology	Progressive road inundation; water-height range 1 cm – 1 m 

Response strategies	R1: alternative destinations; R2: 50% remote-work car ban; R3: bus-lane prioritization 

Socioeconomic layer	Static patches with population density and vulnerability classifier 

Trip attractors	Commercial stores and public services (static agents) 

KPIs	Throughput (M), Efficiency (S), Redundancy (R), Entropy (Q), Theil-T 

________________________________________
## Sample Insights
The model reveals that Larissa flood disruption hits vulnerable groups disproportionately and that R2 maximises aggregate efficiency yet degrades vulnerable-specific serviceability . Specific findings:
Performance under average flood (Table 5.6 in )
Metric	Do nothing	R1	R2	R3
Trip ends (general)	29.926	26.467 (−11.56%)	24.807 (−17.10%)	25.205 (−15.77%)
Trip ends (vulnerable)	0.712	0.626 (−12.04%)	0.735 (+3.21%)	0.609 (−14.49%)
Throughput	0.209	0.224 (+7.00%)	0.227 (+8.71%)	0.225 (+7.61%)
Redundancy	−1.934	−1.590 (+17.80%)	−50.389 (−0.01%)	−1.794 (+7.23%)
Entropy	0.584	0.594 (+1.72%)	−1.575 (+18.55%)	0.598 (+2.37%)
Theil-T	24.463	13.709 (−43.96%)	0.590 (+1.07%)	16.192 (−33.81%) 

Equity-load degradation
As flood inundation depths rise, the model quantifies a non-linear degradation in travel efficiency across the road network, particularly in the districts surrounding the riverbanks . The vulnerable population appears more affected, experiencing an average reduction of 13.51%, compared to an average reduction of 11.58% for the general population 
Response-strategy signature
R1 produced the largest equity-disparity reduction from the very first deployment phase 
R2 maximised aggregate efficiency but degraded vulnerable-specific serviceability .
R3 is the most effective response for the maintenance of the serviceability levels of all the population, by providing a robust transit backbone that remains resilient even as private-mode availability contracts .
Flood-typology gradient
The degradation under flood has local peaks and inconsistent trends: some districts lose their routes earlier than others, and the vulnerable-group penalty is consistently 2 percentage points larger than the general-population penalty .
________________________________________
## Citation
If you use this model in academic work, please cite the parent deliverable:
Tzioutziou, A., Tsami, M., Xenidis, Y., et al. D3.4 Mobility Triage Analysis DSS. AntifragiCity Project, 2026. Section 5.3.3 — Larissa .
________________________________________
## References
Source document: D3.4 Mobility Triage Analysis DSS — Section 5.3.3 Larissa, including subsections 5.3.3.1 Model Development, 5.3.3.2 Definition of Parameters and Scenarios, and 5.3.3.3 Simulations' Results 
OpenStreetMap — Source of the road and bus networks.
