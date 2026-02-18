flowchart TB
    %% Main downward flow
    subgraph FoodLogging["Food Logging"]
        FL1["Food Logging"]
        FL2["Search Food"]
        FL3["Log Food"]
        
        FL1 --> FL2
    end

    %% Backend section
    subgraph Backend["Backend"]
        direction TB
        BR1["Backend Server"]
        BR2["Rate Limit Check"]
        BR3["FatSecret API"]
    end

    %% Connect both sections
    FL2 --> BR1
    BR1 --> BR2
    BR2 -- "Denied" --> FL1
    BR2 -- "Allowed" --> BR3
    
    BR3 -. "Retrieve Food" .-> FL3