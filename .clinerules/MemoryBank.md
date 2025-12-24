# System Incremental Memory Bank

## Project Overview
**Project Name:** System Incremental
**Type:** Roblox Incremental/Idle Game
**Language:** Luau (Roblox Lua)
**Framework:** Roblox Studio

## Core Systems

### 1. Prestige System
- **PrestigeService.luau** - Main prestige logic
- **PrestigeConfig.luau** - Configuration for prestige nodes and requirements
- **PrestigePointsService.luau** - Manages prestige points currency
- **PrestigeNodeService.luau** - Handles prestige node unlocking and upgrades

### 2. Upgrade System
- **UpgradeService.luau** - Core upgrade management
- **UpgradeConfig.luau** - Upgrade definitions and costs
- **PrestigeUpgradesConfig.luau** - Prestige-specific upgrades
- **UpgradeController.luau** - Client-side upgrade handling

### 3. Production System
- **ProductionService.luau** - Resource generation and production logic

### 4. Analytics & Data
- **AnalyticsTrackerService.luau** - Game analytics and telemetry
- **AnalyticsConfig.luau** - Analytics configuration
- **PlayerDataService.luau** - Player data persistence

### 5. Social & Community
- **SocialGoalsService.luau** - Social objectives and goals
- **SocialGoalsConfig.luau** - Social goal definitions
- **CommunityController.luau** - Community features
- **CommunityRewardsConfig.luau** - Community reward system

### 6. Store & Monetization
- **StoreUIController.luau** - Store interface
- **MonetizationService.luau** - In-game purchases

### 7. Leaderboards
- **LeaderboardService.luau** - Global and social leaderboards

### 8. Testing
- **TestService.lua** - Server-side testing framework
- **TestController.lua** - Client-side testing

## Configuration Files
- **default.project.json** - Roblox project configuration
- **aftman.toml** - Package manager configuration

## Key Features
- Incremental resource generation
- Prestige system with branching paths
- Social goals and community rewards
- Analytics tracking
- Leaderboards
- Store integration

## Development Notes
- Uses Luau for both client and server scripts
- Modular service architecture
- Configuration-driven design
- Analytics integration for player behavior tracking

## Recent Changes
- Last commit: 20d1980aad4b6fb6d271534c779d2f8482e476d7
- Project structure follows Roblox best practices
- Comprehensive service-based architecture

## TODO Items
- [ ] Add detailed documentation for each service
- [ ] Document API endpoints and data structures
- [ ] Add performance optimization notes
- [ ] Document testing procedures
- [ ] Add deployment and release notes
