# High-Level Diagrams

This document contains Mermaid flowcharts illustrating the Jasfo platform's key workflows: the weekly pipeline, model routing across layers, cost flow through the system, and data flow from input to output.

## Weekly Pipeline Flow

```mermaid
flowchart TD
    Start["Monday 00:00 IST - Pipeline Triggered"]
    Start --> S1["Collection Layer<br/>10,000 Companies<br/>Firecrawl + Apify"]
    S1 --> S2["Normalization Layer<br/>DeepSeek V4 Flash<br/>~9,500 Survive"]
    S2 --> S3["Verification Layer<br/>MiMo V2.5<br/>~8,000 Survive"]
    S3 --> S4["Feature Engineering<br/>DeepSeek V4 Flash"]
    S4 --> S5["Specialist Agents<br/>5 Parallel Agents<br/>DeepSeek + MiMo<br/>~5,000 Survive"]
    S5 --> S6["Consensus Engine<br/>MiMo V2.5<br/>~2,000 Survive"]
    S6 --> S7["Lead Memory &<br/>Change Detection<br/>DeepSeek V4 Flash"]
    S7 --> S8["Cost Gate<br/>Score Threshold Check"]
    
    S8 -->|"Score ≥ 70"| S9["Contact Enrichment<br/>DeepSeek V4 Flash<br/>~200 Companies"]
    S8 -->|"Score < 70"| Drop1["Dropped<br/>Queued for Next Run"]
    
    S9 --> S10["Commercial Strategy<br/>MiMo V2.5"]
    S10 --> S11["Judge Layer<br/>Claude Sonnet 4<br/>~20-30 Leads"]
    S11 --> S12["Evidence Package<br/>Generated"]
    S12 --> S13["Telegram Notification<br/>Sent to Broker"]
    S12 --> S14["CSV / Excel Export<br/>Downloaded by Broker"]
    
    S13 --> S15["Broker Reviews Leads<br/>2-3 Hours"]
    S15 --> S16["Outreach Begins<br/>Monday-Tuesday"]
```

## Weekly Pipeline Timeline

```mermaid
gantt
    title Weekly Pipeline Schedule
    dateFormat  HH:mm
    axisFormat  %H:%M
    
    section Collection
    Firecrawl Scraping     :c1, 00:00, 1h
    Apify Fallback         :c2, 00:30, 1h
    
    section AI Processing
    Normalization          :a1, 01:00, 30m
    Verification           :a2, 01:30, 45m
    Feature Engineering    :a3, 02:15, 30m
    Specialist Agents (5)  :a4, 02:45, 1h
    Consensus              :a5, 03:45, 30m
    
    section Memory & Gate
    Lead Memory + Change   :m1, 04:15, 30m
    Cost Gate              :m2, 04:45, 5m
    
    section Enrichment
    Contact Enrichment     :e1, 04:50, 30m
    Commercial Strategy    :e2, 05:20, 20m
    
    section Judge
    Claude Sonnet 4 Eval   :j1, 05:40, 15m
    
    section Delivery
    Export Generation      :d1, 05:55, 5m
    Telegram Notification  :d2, 06:00, 1m
    
    section Broker
    Lead Review            :b1, 09:00, 2h
```

## Model Routing Flow

```mermaid
flowchart LR
    subgraph Free_Tier["Free Tier - 80% of Volume"]
        DS["DeepSeek V4 Flash<br/>$0.15-0.30/1M tokens"]
        DS --> L1["Layer 2: Normalization"]
        DS --> L2["Layer 4: Feature Engineering"]
        DS --> L3["Layer 5: Growth Agent"]
        DS --> L4["Layer 6: Space Agent"]
        DS --> L5["Layer 8: Industry Agent"]
        DS --> L6["Layer 9: Decision Agent"]
        DS --> L7["Layer 12: Change Detection"]
        DS --> L8["Layer 14: Contact Enrichment"]
    end
    
    subgraph Mid_Tier["Mid Tier - 15% of Volume"]
        MM["MiMo V2.5<br/>$0.50-1.00/1M tokens"]
        MM --> M1["Layer 3: Verification"]
        MM --> M2["Layer 7: Financial Agent"]
        MM --> M3["Layer 10: Consensus"]
        MM --> M4["Layer 15: Commercial Strategy"]
    end
    
    subgraph Premium_Tier["Premium Tier - 5% of Volume"]
        CS4["Claude Sonnet 4<br/>$3-15/1M tokens"]
        CS4 --> P1["Layer 16: Judge"]
    end
    
    subgraph Routing_Logic["Routing Logic"]
        RL1{"Task requires<br/>reasoning depth?"}
        RL1 -->|"No"| RL2{"Task requires<br/>multi-source verification?"}
        RL1 -->|"Yes"| RL3{"Task is final<br/>quality gate?"}
        RL2 -->|"No"| DS
        RL2 -->|"Yes"| MM
        RL3 -->|"No"| MM
        RL3 -->|"Yes"| CS4
    end
```

## Cost Flow Diagram

```mermaid
flowchart TD
    subgraph Free_Ops["Free Operations - 80% of Companies"]
        A1["Firecrawl (Existing Plan)"] --> A2["Supabase Free Tier"]
        A1 --> A3["SerpAPI Free Tier"]
        A1 --> A4["RSS Feeds"]
        A1 --> A5["Public Registries (MCA, GST)"]
    end
    
    subgraph Low_Cost_AI["Low-Cost AI - 15% of Companies"]
        B1["DeepSeek V4 Flash<br/>(Normalization, Features,<br/>Specialist Agents)"]
    end
    
    subgraph Mid_Cost_AI["Mid-Cost AI - 4% of Companies"]
        C1["MiMo V2.5<br/>(Verification, Consensus,<br/>Strategy)"]
    end
    
    subgraph High_Cost_Ops["High-Cost Operations - 1% of Companies"]
        D1["Apify Actors<br/>$20-30/mo"]
        D2["Claude Sonnet 4<br/>Judge Layer<br/>$5-10/mo"]
    end
    
    subgraph Total_Cost["Total Monthly Cost: Under $50"]
        E1["Make.com: $9"]
        E2["Apify: $25"]
        E3["AI Inference: $10"]
        E4["Railway: $5"]
        E5["Total: ~$49"]
    end
    
    A1 --> B1
    B1 --> C1
    C1 --> D1
    C1 --> D2
    
    E1 -.-> Total_Cost
    E2 -.-> Total_Cost
    E3 -.-> Total_Cost
    E4 -.-> Total_Cost
```

## Data Flow Diagram

```mermaid
flowchart LR
    subgraph Input["Input"]
        I1["Company List<br/>10,000 Companies"]
    end
    
    subgraph Collection["Collection"]
        C1["Firecrawl<br/>Website Scraping"]
        C2["Apify<br/>LinkedIn + Maps"]
        C3["Free APIs<br/>SerpAPI, Registries"]
    end
    
    subgraph Storage["Storage - Supabase"]
        S1["Raw Scraped Data"]
        S2["Normalized Records"]
        S3["Verified Claims"]
        S4["Feature Vectors"]
        S5["Agent Outputs"]
        S6["Scores & Memory"]
        S7["Evidence Packages"]
        S8["Exports"]
    end
    
    subgraph Processing["Processing - AI Models"]
        P1["DeepSeek V4 Flash<br/>Bulk Processing"]
        P2["MiMo V2.5<br/>Reasoning Tasks"]
        P3["Claude Sonnet 4<br/>Final Judge"]
    end
    
    subgraph Output["Output"]
        O1["Telegram Summary"]
        O2["CSV Export"]
        O3["Excel Report"]
        O4["Evidence Package"]
    end
    
    I1 --> C1
    I1 --> C2
    I1 --> C3
    
    C1 --> S1
    C2 --> S1
    C3 --> S1
    
    S1 --> P1 --> S2
    S2 --> P2 --> S3
    S3 --> P1 --> S4
    S4 --> P1 --> S5
    S5 --> P2 --> S6
    S6 --> P3 --> S7
    
    S7 --> O1
    S7 --> O2
    S7 --> O3
    S7 --> O4
```
