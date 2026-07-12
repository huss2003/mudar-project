# Deployment Diagrams

This document contains Mermaid deployment diagrams illustrating the Jasfo platform's infrastructure: service topology across providers, data storage layout, network flow, and service dependencies.

## Deployment Architecture

```mermaid
graph TD
    subgraph Internet["Internet"]
        CDN["Cloudflare CDN<br/>DNS, DDoS, Caching"]
    end
    
    subgraph Railway["Railway Cloud"]
        Web["Web Service<br/>(Lightweight API)"]
        Utils["Utility Scripts<br/>(Scheduled Tasks)"]
    end
    
    subgraph Supabase["Supabase Cloud"]
        DB["PostgreSQL Database<br/>Companies, Scores, Memory"]
        Auth["Auth Service<br/>(Service Role Key)"]
        Storage["File Storage<br/>(Export Files)"]
    end
    
    subgraph Make["Make.com Cloud"]
        Pipeline["Weekly Pipeline Scenario<br/>14-Layer Orchestration"]
        ErrorHandler["Error Handler Scenario<br/>Failure Logging"]
        Scheduler["Scheduled Trigger<br/>Monday 00:00 IST"]
    end
    
    subgraph Scraping["Scraping Services"]
        Firecrawl["Firecrawl API<br/>Primary Scraper"]
        Apify["Apify Cloud<br/>Secondary Scraper"]
        SerpAPI["SerpAPI<br/>Search Results"]
    end
    
    subgraph AI["AI Services"]
        OpenCode["OpenCode GO<br/>Unified AI API"]
        DeepSeek["DeepSeek V4 Flash<br/>Bulk Processing"]
        MiMo["MiMo V2.5<br/>Reasoning Tasks"]
        Anthropic["Anthropic Direct API<br/>Claude Sonnet 4"]
    end
    
    subgraph Broker["Broker Environment"]
        Telegram["Telegram Bot<br/>Notifications"]
        Email["SMTP Email<br/>Outreach"]
        Local["Local Machine<br/>CSV/Excel Review"]
    end
    
    CDN --> Web
    
    Pipeline --> Firecrawl
    Pipeline --> Apify
    Pipeline --> SerpAPI
    Pipeline --> OpenCode
    Pipeline --> Anthropic
    Pipeline --> DB
    Pipeline --> Telegram
    Pipeline --> ErrorHandler
    Scheduler --> Pipeline
    
    OpenCode --> DeepSeek
    OpenCode --> MiMo
    
    Web --> DB
    Utils --> DB
    Utils --> Storage
    
    Broker --> Telegram
    Broker --> Email
    Broker --> Local
    Local --> Web
    
    ErrorHandler --> DB
```

## Data Storage Architecture

```mermaid
graph TD
    subgraph Supabase_Storage["Supabase Database"]
        subgraph Schemas["Schema: public"]
            T1["companies<br/>Core company profiles"]
            T2["scraped_data<br/>Raw scraper output"]
            T3["normalized_data<br/>Cleaned records"]
            T4["verified_claims<br/>Verified data points"]
            T5["feature_vectors<br/>Extracted features"]
            T6["agent_outputs<br/>Specialist agent results"]
            T7["consensus_scores<br/>Unified scores"]
            T8["lead_memory<br/>Historical records"]
            T9["change_deltas<br/>Detected changes"]
            T10["contacts<br/>Decision-maker contacts"]
            T11["strategies<br/>Outreach strategies"]
            T12["evidence_packages<br/>Full evidence packages"]
        end
        
        subgraph Infrastructure["Schema: infra"]
            I1["pipeline_logs<br/>Run history"]
            I2["error_logs<br/>Failure records"]
            I3["cost_logs<br/>API spend tracking"]
            I4["reflection_data<br/>Calibration records"]
        end
        
        subgraph Storage["Storage Buckets"]
            S1["exports<br/>CSV/Excel/PDF files"]
            S2["backups<br/>Database backups"]
        end
    end
    
    T1 --> T2
    T2 --> T3
    T3 --> T4
    T4 --> T5
    T5 --> T6
    T6 --> T7
    T7 --> T8
    T8 --> T9
    T9 --> T12
    T10 --> T12
    T11 --> T12
    T12 --> S1
```

## Network Flow Diagram

```mermaid
graph LR
    subgraph External["External Network"]
        FC["Firecrawl<br/>api.firecrawl.dev"]
        AF["Apify<br/>api.apify.com"]
        SP["SerpAPI<br/>serpapi.com"]
        DS["DeepSeek<br/>api.deepseek.com"]
        MM["MiMo<br/>api.mimo.dev"]
        AN["Anthropic<br/>api.anthropic.com"]
        MK["Make.com<br/>make.com"]
        SB["Supabase<br/><project>.supabase.co"]
    end
    
    subgraph Make_Network["Make.com (Orchestrator)"]
        Scenarios["Pipeline Scenarios"]
        HTTP["HTTP Modules"]
        JSON["JSON Processors"]
        Err["Error Handlers"]
    end
    
    subgraph Src["Source IPs"]
        MK_IP["Make.com IP Pool"]
        RL_IP["Railway IP Pool"]
    end
    
    MK_IP --> FC
    MK_IP --> AF
    MK_IP --> SP
    MK_IP --> DS
    MK_IP --> MM
    MK_IP --> AN
    MK_IP --> SB
    
    RL_IP --> SB
    RL_IP --> AN
    
    MK_IP -->|"Webhook Callback"| RL_IP
```

## Service Dependency Diagram

```mermaid
graph TD
    Pipeline("Weekly Pipeline") -->|"Depends on"| FC["Firecrawl"]
    Pipeline -->|"Depends on"| AF["Apify"]
    Pipeline -->|"Depends on"| DS["DeepSeek V4 Flash"]
    Pipeline -->|"Depends on"| MM["MiMo V2.5"]
    Pipeline -->|"Depends on"| CS["Claude Sonnet 4"]
    Pipeline -->|"Depends on"| SB["Supabase"]
    Pipeline -->|"Depends on"| TG["Telegram Bot API"]
    
    Pipeline -->|"Reports to"| EH["Error Handler"]
    EH -->|"Logs to"| SB
    
    WebService("Railway Web Service") -->|"Depends on"| SB
    WebService -->|"Serves"| Broker["Broker Browser"]
    
    LocalScripts("Utility Scripts") -->|"Depends on"| SB
    
    subgraph Critical["Critical Path Dependencies"]
        FC
        SB
        DS
    end
    
    subgraph Important["Important Dependencies"]
        AF
        MM
        TG
    end
    
    subgraph Optional["Optional Dependencies"]
        CS["Claude Sonnet 4<br/>(Fallback: MiMo)"]
        SP["SerpAPI<br/>(Fallback: Firecrawl)"]
    end
    
    style Critical fill:#e1f5fe,stroke:#01579b
    style Important fill:#fff3e0,stroke:#e65100
    style Optional fill:#f3e5f5,stroke:#4a148c
```

## Technology Provider Map

```mermaid
flowchart LR
    subgraph Providers["Service Providers"]
        direction TB
        M["Make.com<br/>Orchestration"]
        SB["Supabase<br/>Database"]
        FC["Firecrawl<br/>Primary Scraper"]
        AP["Apify<br/>Secondary Scraper"]
        OG["OpenCode GO<br/>AI Routing"]
        AD["Anthropic<br/>Claude Sonnet 4"]
        RW["Railway<br/>Hosting"]
        CF["Cloudflare<br/>CDN / DNS"]
        TG["Telegram<br/>Notifications"]
    end
    
    subgraph Monthly_Cost["Monthly Cost Allocation"]
        direction TB
        C1["Make.com: $9"]
        C2["Apify: $25"]
        C3["AI Inference: $10"]
        C4["Railway: $5"]
        C5["Total: $49"]
    end
    
    M -.->|"$0-9/mo"| C1
    AP -.->|"$20-30/mo"| C2
    OG -.->|"~$5/mo"| C3
    AD -.->|"~$5/mo"| C3
    RW -.->|"~$5/mo"| C4
    
    Service["Jasfo Platform"] --> M
    Service --> SB
    Service --> FC
    Service --> AP
    M --> OG
    M --> AD
    Service --> RW
    Service --> CF
    Service --> TG
```
