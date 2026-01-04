# Tech Context

## Technologies Used

### Core Technologies
- **Roblox Studio**: Primary development environment for the game
- **Luau**: Roblox's scripting language (Lua-based)
- **Rojo**: Development tool for Roblox projects
- **Aftman**: Cross-platform toolchain manager

### Architecture Components
- **InitManager**: Service initialization and lifecycle management
- **ModuleLoader**: Dynamic module loading system
- **DataStore**: Roblox's persistent data storage solution
- **Remote Events/Functions**: Client-server communication

### Development Setup
- **Project Structure**: Organized under `/src` directory with client/server/shared separation
- **Service Pattern**: Modular services for different game systems
- **Anti-Cheat System**: Request validation and player state auditing
- **Error Handling**: Comprehensive logging and graceful degradation

### Technical Constraints
- **Roblox Platform Limitations**: Script execution limits, memory constraints
- **DataStore Rate Limits**: 60 writes per minute per user
- **Network Latency**: Client-server communication delays
- **Security Requirements**: Anti-cheat measures and data validation

### Dependencies
- **Roblox API**: Core game engine and services
- **DataStoreService**: Player data persistence
- **ReplicatedStorage**: Shared resources between client and server
- **Players Service**: Player management and events

### Tool Usage Patterns
- **Rojo**: Project building and synchronization
- **Aftman**: Toolchain management (Rojo v7.7.0-rc.1)
- **ModuleLoader**: Automatic service registration and initialization
- **InitManager**: Controlled service startup phases

### Performance Considerations
- **Memory Management**: Efficient data structures and cleanup
- **Network Optimization**: Batch operations and caching
- **Script Optimization**: Efficient loops and minimal API calls
- **UI Performance**: Responsive interfaces with minimal redraws
- **Error Handling**: Robust error handling and graceful degradation
- **Fallback Systems**: Comprehensive fallback modules for module loading issues
- **Analytics Integration**: Performance monitoring and error tracking
