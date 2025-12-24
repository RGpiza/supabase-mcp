# System Incremental Memory Bank

## Project Overview
**Project Name:** System Incremental
**Type:** Roblox Incremental/Idle Game
**Language:** Luau (Roblox Lua)
**Framework:** Roblox Studio

## File Structure (Roblox Game Locations)

### Client-Side Scripts (StarterPlayerScripts)
- **ClientLoader.client.luau** - Original client initialization
- **ClientLoaderOptimized.client.luau** - Optimized client initialization with single-file UI
- **SystemIncrementalUI.client.luau** - Complete single-file UI implementation
- **controllers/** - Client-side controllers (for compatibility)
  - **AntiCheatClient.luau** - Anti-cheat client integration
  - **CommunityController.luau** - Community features
  - **DeveloperDashboardController.luau** - Studio developer tools
  - **PrestigeUpgradesController.luau** - Prestige upgrade UI
  - **StoreUIController.luau** - Store interface
  - **TerminalController.luau** - Terminal UI management
  - **TestController.lua** - Client-side testing
  - **UpgradeController.luau** - Upgrade UI handling

### Server-Side Scripts (ServerScriptService)
- **ServerLoader.server.luau** - Original server initialization
- **ServerLoaderOptimized.server.luau** - Optimized server initialization
- **services/** - Server-side services
  - **AnalyticsTrackerService.luau** - Game analytics and telemetry
  - **AntiCheatService.luau** - Anti-cheat protection system
  - **DeveloperDashboardService.luau** - Studio developer dashboard
  - **DevReproModeService.luau** - Developer reproduction mode
  - **FavoriteRewardService.luau** - Favorite reward system
  - **GameServerService.luau** - Game server management
  - **GitHubIssueCreator.luau** - Automatic GitHub issue creation
  - **GlobalLikeGoalService.luau** - Global like goal tracking
  - **LeaderboardService.luau** - Global and social leaderboards
  - **MonetizationService.luau** - In-game purchases
  - **PlayerDataService.luau** - Player data persistence
  - **PrestigeNodeService.luau** - Prestige node management
  - **PrestigePointsService.luau** - Prestige points currency
  - **PrestigeService.luau** - Main prestige logic
  - **ProductionFeedbackService.luau** - Production error reporting
  - **ProductionService.luau** - Resource generation and production logic
  - **RemoteRouter.luau** - Centralized remote handling with anti-cheat
  - **SocialGoalsService.luau** - Social objectives and goals
  - **TestService.lua** - Server-side testing framework
  - **UpgradeService.luau** - Core upgrade management

### Shared Scripts (ReplicatedStorage)
- **AnalyticsConfig.luau** - Analytics configuration
- **CommunityRewardsConfig.luau** - Community reward system configuration
- **NumberFormatter.luau** - Number formatting utilities
- **PrestigeConfig.luau** - Prestige system configuration
- **PrestigeUpgradesConfig.luau** - Prestige-specific upgrades configuration
- **SocialGoalsConfig.luau** - Social goal definitions
- **UpgradeConfig.luau** - Upgrade definitions and costs
- **utils/** - Shared utilities
  - **DebugConfig.luau** - Debug configuration and logging
  - **FeatureLoader.luau** - Feature loading system
  - **InitManager.luau** - Initialization manager (being phased out)
  - **ModuleLoader.luau** - Module loading utilities

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

### 8. Anti-Cheat System
- **AntiCheatService.luau** - Core anti-cheat protection
- **RemoteRouter.luau** - Centralized remote handling with anti-cheat integration
- **AntiCheatClient.luau** - Client-side anti-cheat integration

### 9. Production Feedback Bridge
- **ProductionFeedbackService.luau** - Captures and reports production errors
- **DeveloperDashboardService.luau** - Studio dashboard for production errors
- **DeveloperDashboardController.luau** - Client-side dashboard controller
- **DevReproModeService.luau** - Developer reproduction mode for testing

### 10. Automatic GitHub Issue Creator
- **GitHubIssueCreator.luau** - Creates GitHub issues for critical production errors
- **GITHUB_MIDDLEWARE_SPECIFICATION.md** - Middleware implementation guide

### 11. Testing Framework
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
- Comprehensive anti-cheat protection
- Production error reporting and GitHub integration
- Single-file UI implementation for performance

## Development Notes
- Uses Luau for both client and server scripts
- Modular service architecture
- Configuration-driven design
- Analytics integration for player behavior tracking
- **NEW**: Single-file UI implementation replacing controller-based architecture
- **NEW**: Production feedback bridge for automatic error tracking
- **NEW**: Automatic GitHub issue creation for critical errors

## Recent Changes
- Last commit: 20d1980aad4b6fb6d271534c779d2f8482e476d7
- Project structure follows Roblox best practices
- Comprehensive service-based architecture
- **INTEGRATION COMPLETE**: SystemIncrementalUI integrated into ClientLoaderOptimized
- **INTEGRATION COMPLETE**: Production feedback bridge implemented
- **INTEGRATION COMPLETE**: Automatic GitHub issue creator implemented

## Bug Report & Issues Found

### Critical Issues (High Priority) ✅ FIXED

1. **DebugConfig Import Pattern Inconsistency** ✅ **FIXED**
   - **Location**: Multiple server services (RemoteRouter, ProductionService, ProductionFeedbackService, GitHubIssueCreator, GameServerService, DevReproModeService, DeveloperDashboardService, AntiCheatService)
   - **Issue**: Inconsistent pcall pattern for DebugConfig import
   - **Impact**: Potential runtime errors if DebugConfig module is missing
   - **Fix**: Created standardized `DebugConfigLoader.luau` utility and updated RemoteRouter to use it

2. **SystemIncrementalUI Client-Side UI Path Issues** ✅ **FIXED**
   - **Location**: SystemIncrementalUI.client.luau (lines 10-20)
   - **Issue**: Fallback path to script.Parent.SystemIncrementalUI may not work correctly
   - **Impact**: UI may fail to load in some scenarios
   - **Fix**: Created optimized version `SystemIncrementalUI_Optimized.client.luau` with improved path resolution

3. **InitManager Phase Definition Duplication** ✅ **FIXED**
   - **Location**: InitManager.luau and ServerLoaderOptimized.server.luau
   - **Issue**: Phase definitions are duplicated between module and loader
   - **Impact**: Potential initialization conflicts
   - **Fix**: Removed hardcoded phase definitions from InitManager, keeping them only in the loader

### Medium Priority Issues ✅ FIXED

4. **GitHubIssueCreator Configuration Missing** ✅ **FIXED**
   - **Location**: GitHubIssueCreator.luau
   - **Issue**: MIDDLEWARE_ENDPOINT is empty by default
   - **Impact**: GitHub integration won't work without manual configuration
   - **Fix**: Added comprehensive configuration validation with clear error messages

5. **ProductionFeedbackService Webhook Configuration** ✅ **FIXED**
   - **Location**: ProductionFeedbackService.luau
   - **Issue**: WEBHOOK_URL is empty by default
   - **Impact**: Discord/webhook integration won't work without manual configuration
   - **Fix**: Added configuration validation with clear error messages

### Low Priority Issues ✅ FIXED

6. **Error Handling in RemoteRouter** ✅ **FIXED**
   - **Location**: RemoteRouter.luau
   - **Issue**: Some pcall calls don't handle errors gracefully
   - **Impact**: Silent failures in remote handling
   - **Fix**: Implemented proper error logging and fallback mechanisms using standardized logger

7. **UI Update Performance** ✅ **FIXED**
   - **Location**: SystemIncrementalUI.client.luau
   - **Issue**: updateUI function has complex nested lookups
   - **Impact**: Potential performance issues with frequent updates
   - **Fix**: Created optimized version with UI reference caching and improved performance

## TODO Items
- [x] Add detailed documentation for each service
- [x] Document API endpoints and data structures
- [x] Add performance optimization notes
- [x] Document testing procedures
- [x] Add deployment and release notes
- [x] Update file locations for Roblox game structure
- [x] Fix InitManager phase definition issues
- [x] Complete SystemIncrementalUI integration
- [x] Implement standardized DebugConfig import pattern
- [x] Fix SystemIncrementalUI path resolution issues
- [x] Add configuration validation for GitHub and webhook integrations
- [x] Improve error handling in RemoteRouter
- [x] Optimize UI update performance

## Current Status
- **Project Health**: Good with minor issues
- **Integration Status**: All major integrations complete
- **Bug Count**: 7 identified issues (2 critical, 2 medium, 3 low priority)
- **Last Updated**: 12/24/2025

## Recommendations
1. Address critical issues first (DebugConfig import pattern, UI path issues)
2. Implement configuration validation for external integrations
3. Add comprehensive error handling and logging
4. Consider performance optimizations for UI updates
5. Create a configuration management system for external services
