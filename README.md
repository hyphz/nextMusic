# nextMusic Driver

This is my attempt at writing a music driver for the Spectrum Next. This is quite possibly a terrible area given that I haven't done this before and there are tons of people with much more experience who are likely to be doing it too. But there we go.

Currently it supports only a single chip because there is no emulator in existence that I am aware of that actually emulates the 3 AY + SID configuration of the Next. But the architecture to use all of those is hopefully in place.

# Input format

Value at `Tempo` gives the number of frames per beat. The Next runs at 50 FPS, so this is roughly the BPM divided by 3000. However, there is no way to enter fractional note lengths because the Next supports only integer arithmetic, so the "beat" length has to be the length of the shortest note in the whole piece and everything else specified based on that.

### Master Program

The data at `Music` is the "master program" that invokes patterns. Each entry consists of a time, in **beats**, to wait before the command (which can be 0), then a command and its parameters. Currently there's only one command:

`<delta-time> <voice-number> <ll> <hh>` Start the pattern at address `$hhll` playing on voice `voicenumber`. 1-3 are the AY1 voices, 5-7 the AY2, and 9-11 the AY3. 4, 8, 12, and 16 are noise voices and 13-15 is the SID, but it doesn't know what to do with those yet.

Note that you can start a pattern in the middle by just using an address that's in the middle of a pattern as long as it's the first byte of a pattern command, and you can cut a pattern off in the middle by having a master command occur while it's playing. Patterns can be any length and overlap each other when playing however you want. To play several patterns at once, just use several start commands one after the other with 0 delta time.

So what's a pattern? 

### Patterns

It's another list of commands. As before, each one consists of a time in beats to wait, then a command. These are:

`<delta-time> <note-number>` Play the numbered note. Notes run from 0-95 and 96 is a rest. 

`<delta-time> $80` Loop back to the start of the pattern.

`<delta-time> $81` Set the current location (immediately after the command) as the loopback point for future lops.

`<delta-time> $82 <ll> <hh>` Set the instrument (amplitude table) address to $hhll.

`<delta-time> $83` Disables maintenance on this voice. This means no new notes will sound and envelopes won't play. You'd probably usually use this after playing a rest to make the voice go silent, but if you want a continuously sounding uniform tone that takes no CPU time to maintain, who am I to say you're wrong?

### Amplitude Tables (Instruments)

An Instrument currently is represented by a series of three addresses:

`<Attack-table ll> <hh> <Release-table ll> <hh> <Onebeat-table ll> <hh>`

Each of these gives the address of a table in the following format:

`<Amplitude-value> <Offset>`

`Amplitude-value` is the value to store in the AY amplitude register for the playing voice, and `offset` is the address offset to the next entry in the table, based on the base address of the current entry. So the most common offset is 2, to move ahead two bytes and thus play the next entry in the table. You can also use 0 to loop on a single amplitude value, or negative value to loop back more than one value.

The difference between the three tables is that `attack-table` is used when a voice begins sounding and constantly from then on (so it's not really just attack, but hey) until the note is on its last beat of sounding, whereupon `release-table` is used. If the note is only one beat long, `onebeat-table` is used in place of either.

