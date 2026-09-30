Config = {}

-- Centre of Legion Square park and how far the music carries.
Config.Center = vec3(195.5, -934.0, 30.7)
Config.FullVolumeRadius = 40.0   -- metres: full (gentle) volume inside this
Config.FadeOutRadius = 90.0      -- metres: silent beyond this, smooth fade in between

Config.Volume = 0.35             -- master volume, 0.0 - 1.0 (keep it low for background music)
Config.SpawnFadeInMs = 8000      -- slow fade-in right after a player spawns / loads in
Config.FadeMs = 1500             -- fade speed when walking in/out of the park
Config.MuteInVehicle = false     -- true = music fades out while you're in a vehicle
Config.CheckIntervalMs = 500

-- Music:
--   Drop .ogg / .mp3 / .wav / .webm files into html/music/ and restart the resource.
--   They are found automatically and play one after another, then loop back to the start.
--   If the folder is empty, built-in generated ambient music plays instead.
--   Only use music you have the rights to play on your server.
Config.Shuffle = false           -- true = random order each time round the playlist

Config.Command = 'parkmusic'     -- /parkmusic toggles the music on/off for that player (remembered)
