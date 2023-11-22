# Frequently Asked Questions
How do I make parties with Matchmaking Service?

MMS does not handle party creation for you. All MMS does is ensure players queued as a group will get into the same game. You can queue a party using [`QueueParty(players, ratingType, map)`](https://steven4547466.github.io/MatchmakingService/maindocs/#queueing-a-party) and you can retrieve a user's party by using [`GetPlayerParty(player)`](https://steven4547466.github.io/MatchmakingService/maindocs/#getting-a-players-party).

---

What does \_\_\_\_\_\_ error mean?

Most of the time, I wouldn't know without doing some experimenting. However, there is an error which you may run into which I have no control over. When you see `MainModule:line: Request Failed.` that means that the Memory Store rejected the request, which usually means it's experiencing disruptions. Make sure to check the [roblox status](http://status.roblox.com/) to see if there's a service disruption.

Other errors that you may see:

- `The rate of requests exceeds the allowed limit`. If you see this, you're making more than `1000 + 100 * (active players across entire game universe)` requests to the memory stores per minute. This usually shouldn't happen, but it could happen if you have a player spamming more than 50 queue and unqueue requests per minute (1 request to add them, 1 request to remove them and each player adds 100 to the limit), but it'd be nearly impossible to take up the whole limit like this because of how many requests you get per user. It'd most likely need to be a targeted attack to break your game. I recommend adding a rate limit to how fast your players can queue and unqueue.

- `Failed to invoke transformation function`. If you see this report it to me asap with as much detail as you can give. It means one of the update functions didn't return as expected and could impact many users of MMS.

- `Code: 4, Error: The provided value is too long`. If you see this, then it usually means you had, on average, more than 100 players queueing for the same map and rating type in the same second. This error happens due to the 1kb size limit (I'm currently in talks with roblox to increase this limit. If it doesn't increase I'll add a way to break the queue so this doesn't happen).

---

Technical details of MMS

Some people ask me technical details of matchmaking service. Don't be afraid to send me questions if you're interested in how the service works!
