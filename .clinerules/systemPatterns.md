# System Patterns

## System Architecture

### Service-Based Architecture
The project follows a modular service-based architecture using the InitManager system for controlled initialization and lifecycle management.

**Core Components:**
- **InitManager**: Central service registry and initialization coordinator
- **ModuleLoader**: Dynamic module loading with InitManager integration
- **Services**: Server-side business logic modules
- **Controllers**: Client-side UI and interaction modules

### Service Lifecycle
1. **Registration**: Services register with InitManager during module loading
2. **Initialization**: InitManager controls service startup in defined phases
3. **Operation**: Services provide functionality through public APIs
4. **Cleanup**: Services can implement cleanup logic on shutdown

### Key Technical Decisions

#### Phase-Based Initialization
- **Core Phase**: Essential services (data storage, core game logic)
- **UI Shell Phase**: User interface components
- **Features Phase**: Lazy-loaded feature modules

#### Data Persistence Strategy
- **PlayerDataService**: Centralized player data management
- **DataStore Integration**: Roblox DataStore for persistent storage
- **Memory Caching**: In-memory caching for performance
- **Auto-Save**: Periodic and event-driven data persistence

#### Communication Patterns
- **Remote Events**: Client-server communication for game actions
- **Remote Functions**: Synchronous client-server calls for data retrieval
- **Anti-Cheat Integration**: Request validation and player state auditing

### Design Patterns in Use

#### Service Pattern
Each major system is implemented as a service with:
- **OnStart()**: Initialization method called by InitManager
- **OnStop()**: Cleanup method for graceful shutdown
- **Public API**: Well-defined interface for other services

#### Event-Driven Architecture
- **Remote Events**: Asynchronous communication for game actions
- **State Changes**: Events for significant game state transitions
- **Player Actions**: Events for player interactions and purchases

#### Data Management Pattern
- **Central Repository**: PlayerDataService as single source of truth
- **Validation**: Input validation and sanitization at service boundaries
- **Audit Trail**: Anti-cheat system for monitoring player actions

### Component Relationships

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Client UI     │◄──►│  RemoteRouter    │◄──►│  Game Services  │
│   Controllers   │    │   (Anti-Cheat)   │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │ PlayerDataService│
                       │   (DataStore)    │
                       └──────────────────┘
```

### Critical Implementation Paths

#### Player Initialization
1. Player joins game → ModuleLoader loads services
2. InitManager initializes core services
3. PlayerDataService loads player data
4. UI controllers initialize with player state

#### Game Action Flow
1. Player triggers action → Client controller
2. Controller validates → RemoteRouter
3. RemoteRouter applies anti-cheat → Game service
4. Service processes → PlayerDataService updates
5. Results returned → UI updated

#### Data Persistence
1. Game state changes → Service calls PlayerDataService
2. Data validated and cached → Memory storage
3. Periodic/auto-save → DataStore persistence
4. Error handling → Retry logic with exponential backoff

### Error Handling Strategy
- **Service-Level**: Each service handles its own errors
- **Graceful Degradation**: Services can operate with reduced functionality
- **Logging**: Comprehensive logging for debugging and monitoring
- **Player Feedback**: User-friendly error messages for client-facing issues
