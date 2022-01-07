# Matchmaking Service

## What is it?
Matchmaking Service is an attempt to bring cross-server matchmaking with built in skill-based matchmaking (if you want to use it). Utilizing the new [Memory Store Service](https://developer.roblox.com/en-us/api-reference/class/MemoryStoreService) for fast-based high throughput potentital, Matchmaking Service will keep up even with bigger games.

Matchmaking Service is made to be easy to use. It exposes a fully documented API to developers so they can enjoy the sweet, sweet theory of programming abstraction. However, if you're interested in the guts of the program, it is fully open source and available on [our github](https://github.com/steven4547466/MatchmakingService). That means you can keep up to date with its development and even contribute, open issues, and request new features all in one place. This makes it easy for our contributors to keep track of everything as well.

## Skill-based matchmaking?
Matchmaking Service provides built in skill-based matchmaking using a luau OpenSkill implementation (which you can find [here](https://devforum.roblox.com/t/openskill-a-skill-based-rating-system-for-matchmaking/1571168)). This means that your players won't have to deal with going against opponents they have no chance at beating and it means that you can provide your players with the amazing rank up feeling... if you choose.

Of course because not everybody likes skill-based matchmaking, it is completely optional. You can disable it as well. If you disable it, anywhere you would normally pass a `ratingType`, just pass `nil`. 

## Getting started
Check out our [getting started](gettingstarted.md) page for more information on how basic implementation of this system works.

## Getting a specific major version
Major versions have breaking changes. Because of this, we've added a way to get a specific major version.

When using `GetSingleton()`, you can pass an options table. One of these options is `MajorVersion`. This will ensure that you don't automatically update to a version with a breaking change. Previous major versions will usually not be updated, so it's recommended to update to the latest version when you have time.

Current allowed values:

- "v1"

Example:
`local MatchmakingService = require(7567983240).GetSingleton({["MajorVersion"]="v1"})`

## Quick fix for many issues
If you encounter an issue, it is best to first note the issue, take a screenshot of any errors and send it to me in a private message on devforum. To quickly fix issues that pop up, just clear the memory.

1. Open your game in roblox (not studio)
2. Press F9 to open the console and navigate to the server logs
3. In the command line type `require(7567983240).GetSingleton():Clear()`
4. Shutdown all running servers to restart your game

This is just a quick fix for many issues that pop up. It might not always work, but if I can't fix the issue at the time, it's a good place to start.