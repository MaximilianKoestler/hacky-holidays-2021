# MinesLazer

*ppc*, *crypto*

## Challenge Information

> Can you clear our path? There appears to be a bunch of mines along our trajectory.

There is a backend server available for this challenge.

### Additional Resources

[`mineslazer.nim`](res/mineslazer.nim)

```nim
import os
import random
import bitops
import strutils
import asyncnet, asyncdispatch

randomize()

proc minesGrid(mines: uint64, steps: uint64): string =
    var grid = ""
    for y in 0..7:
        grid &= "["

        for x in 0..7:
                if steps.testBit(x+y*8):
                    grid &= "Ｄ"
                elif mines.testBit(x+y*8):
                    grid &= "Ｘ"
                else:
                    grid &= "＿"

        grid &= "]\c\L"

    return grid

proc processClient(client: AsyncSocket) {.async.} =
    await client.send("=====================\c\L")
    await client.send("=== MINESLAZER 4000  \c\L")
    await client.send("=====================\c\L")

    await client.send("Use the laser to remotely detonate the mines. \c\L")
    await client.send("Make sure you don't hit any crew members with the laser though! \c\L")

    var mines = rand(uint64)
    var steps = uint64(0)

    while true:
        await client.send("\c\L[?] Enter laser position: ")

        var x, y: int
        let line = await client.recvLine()
        if line == "":
            client.close()
            break

        try:
            let xy = line.split(",", 1)
            assert xy.len == 2

            x = parseInt(xy[0])
            y = parseInt(xy[1])

            assert x >= 0 and x < 8 and y >= 0 and y < 8

        except:
            await client.send("Wrong input.\c\L")
            continue

        if not mines.testBit(x+y*8):
            await client.send("Yikes, you hit something you weren't supposed to hit.\c\L")
            await client.send("Hope you have good insurance, you're on your own.\c\L")
            await client.send(minesGrid(mines, steps))
            client.close()
            break

        steps.setBit(x+y*8)
        mines.clearBit(x+y*8)
        await client.send("Pew pew pew! Bomb successfully detonated!\c\L")
        await client.send(minesGrid(uint64(0), steps))

        if mines == 0:
            await client.send("\c\LWOoOOohOOOO, you've gotten rid of all mines!\c\L")
            await client.send("Here's your flag: " & getEnv("FLAG", "MagicFlag") & "\c\L")
            client.close()
            break

proc serve() {.async.} =
    var server = newAsyncSocket()
    server.setSockOpt(OptReuseAddr, true)
    server.bindAddr(Port(1234))
    server.listen()

    while true:
        let client = await server.accept()
        asyncCheck processClient(client)

asyncCheck serve()
runForever()

```

## Tasks

### [250 points] Firin mah lazer

> Use your laser to remotely detonate all the mines!

## Solution
When we launch the backend server, the website provides us a link such as
`tcp://portal.hackazon.org:17032`.
Just opening the url in a browser does not work, so there is no HTTPS server
behind it.

### Playing a Game

Let's take out the swiss pocket knife to see what we can do.
```
$ nc portal.hackazon.org 17032
=====================
=== MINESLAZER 4000
=====================
Use the laser to remotely detonate the mines.
Make sure you don't hit any crew members with the laser though!

[?] Enter laser position:
```

Wow, we are playing a game! It wants us to enter a position, so let's do just that.

```
...
[?] Enter laser position: 42
Wrong input.
```

Surprising, but ok. How about 2 numbers?

```
...
[?] Enter laser position: 1 2
Wrong input.
```

Ok, now the program behaves a bit picky. We will quickly consult the given source code and come
back here when we have figured out what to do.

```nim
        try:
            let xy = line.split(",", 1)
            assert xy.len == 2

            x = parseInt(xy[0])
            y = parseInt(xy[1])
```

That seems pretty clear, so back to `nc`.

```
...
[?] Enter laser position: 1,2
Pew pew pew! Bomb successfully detonated!
[＿＿＿＿＿＿＿＿]
[＿＿＿＿＿＿＿＿]
[＿Ｄ＿＿＿＿＿＿]
[＿＿＿＿＿＿＿＿]
[＿＿＿＿＿＿＿＿]
[＿＿＿＿＿＿＿＿]
[＿＿＿＿＿＿＿＿]
[＿＿＿＿＿＿＿＿]

[?] Enter laser position:
```

And we continue

```
...
[?] Enter laser position: 6,2
Yikes, you hit something you weren't supposed to hit.
Hope you have good insurance, you're on your own.
[Ｘ＿＿＿Ｘ＿＿＿]
[＿ＸＸ＿＿Ｘ＿＿]
[＿Ｄ＿＿ＸＸ＿Ｘ]
[＿＿Ｘ＿＿Ｘ＿＿]
[ＸＸ＿＿Ｘ＿＿Ｘ]
[＿＿ＸＸＸ＿＿＿]
[Ｘ＿＿＿＿Ｘ＿Ｘ]
[＿Ｘ＿＿ＸＸＸ＿]
```

We lost! But that gives us a lot of information. It seems (and the source code confirms this), that
we need to eliminate all mines (indicated by `X` or `D` in the last output) while not hitting any of
the empty grid spaces.

Once we win, the server will pull the flag from the environment and hand it over:
```nim
        if mines == 0:
            await client.send("\c\LWOoOOohOOOO, you've gotten rid of all mines!\c\L")
            await client.send("Here's your flag: " & getEnv("FLAG", "MagicFlag") & "\c\L")
```

On the server side, the whole grid is represented by a single `uint64` variable and for each
connection this variable is initialized with a random value. That means that not only the mine
positions are random, but also the number of mines placed.

```nim
    var mines = rand(uint64)
```

### Can We Just Get Lucky?

So, playing this game fairly and by hand does not seem like a feasible idea. Minesweeper (here's a
[Link](https://en.wikipedia.org/wiki/Minesweeper_(video_game)) for those born after 2000) is not too
difficult, but there you get at least some information about surrounding grid cells.
However, we would not need to play ourselves, letting a computer do it for us is fair game.
So we should at least estimate if we can expect to win just by trying a lot.

To give us an estimate of how many games we can play, we will just assume that we can finish one
game per second, so in the month we have available for the CTF that amounts to 2.628 E+6 games
[(α)](https://www.wolframalpha.com/input/?i=1+month+in+seconds).

Let us quickly calculate our chances of just winning by luck in any game.
The grid has size 8x8, so there are 64 possible mine positions in total.
To get the probability of winning, we must calculate

`Σ (chance of N mines spawning) * (chance of winning with N mines) for all N between 0 and 64`

The probability of a getting a grid with exactly *N* mines is

`(64 choose N) / 2^64`

So for example we have a chance of `(64 choose 0) / 2^64 = 5.421E-20` [(α)](https://www.wolframalpha.com/input/?i=%2864+choose+0%29+%2F+2%5E64) to just get lucky and land in a game without any mines and win immediately.

The probability to win a game that has spawned exactly *N* mines is then given by

`(64-N)! * N! / 64!`

And so we have everything that we need to calculate our chance of success when we just guess:

`SUM (64 choose N) / 2^64 * (64-N)! * N! / 64! for N from 0 to 64 = 3.524E-18` [(α)](
https://www.wolframalpha.com/input/?i=sum+%28%28%2864+choose+n%29+%2F+2%5E64%29+*+%2864-n%29%21+*+n%21+%2F+64%21%29%2C+n%3D0+to+64)

Well, s**t. This is a bit too low even for 2.6 million guesses. So we will have to cheat 😎.

### Cheating for Fun and Profit

Luckily, we have already spotted a possible vector of attack upon first reading of the source code.
The following line at the top of the program is rather suspicious:

```nim
randomize()
```

It looks like the program is seeding the random number generator exactly once, at server start.
If this is deterministic in any way, we can probably exploit it to predict the mine grids generated
in the future.

We will start by looking at the implementation of `randomize()` from the [Nim standard library](https://github.com/nim-lang/Nim/blob/version-1-4/lib/pure/random.nim#L627).

```nim
when not defined(nimscript) and not defined(standalone):
  import times

  proc randomize*() {.benign.} =
    ## Initializes the default random number generator with a value based on
    ## the current time.
    ##
    ## This proc only needs to be called once, and it should be called before
    ## the first usage of procs from this module that use the default random
    ## number generator.
    ##
    ## **Note:** Does not work for NimScript.
    ##
    ## See also:
    ## * `randomize proc<#randomize,int64>`_ that accepts a seed
    ## * `initRand proc<#initRand,int64>`_
    when defined(js):
      let time = int64(times.epochTime() * 1000) and 0x7fff_ffff
      randomize(time)
    else:
      let now = times.getTime()
      randomize(convert(Seconds, Nanoseconds, now.toUnix) + now.nanosecond)
```

The code path relevant for our implementation is most likely the following:

```nim
      let now = times.getTime()
      randomize(convert(Seconds, Nanoseconds, now.toUnix) + now.nanosecond)
```

So the `randomize()` function takes the current time stamp and passes it to the `randomize(int64)`
variant. This is both good and bad news at the same time. It is **very** good that the seeding is
based on system time because that is, at least to some extent, predictable.
The bad news is that the accuracy of the time stamp is evaluated in nanoseconds. That means that
we will not be able to just guess the seed in a few tries.

### Strategy Talk

Given that the information we have now, we can craft a plan on how to cheat successfully. We will
exploit the two main weaknesses we have uncovered about the server so far:

 1. The random number generator used to place the mines is seeded exactly once on server start and
    reused for each client connection from that point on. That means if we know the state of the
    RNG at any point in time, we can accurately predict any following mine placements
 2. After loosing a round, the server allows us a glance at the whole playing field. This makes our
    attach much easier because we know how the first random grid after server start looks like.

With this, the strategy is clear:

 1. We start the server and play a game until we loose. Then we know the distribution of mines for
    the first call of `rand(uint64)` after seeding and we also have an estimate for the system
    time that the server was started at.
 2. We feed these two pieces of information (first grid and startup time) into a custom program.
    This program tries to seed the RNG with different timestamps in nanosecond accuracy which are
    close to the server startup time. We compute the first mine distribution and repeat this until
    we hit the grid that the server has shown us.
 3. At this point, the server RNG and our local RNG hopefully share their state. So we can just
    generate one more grid locally and use that information to win the game on the server.

### Implementation

To work with nim, we need the tool chain to start with.

```
$ sudo apt-get -y install nim
...
```

We can compile and the original server code using these commands:

```
$ nim c mineslazer.nim
Hint: used config file '/etc/nim/nim.cfg' [Conf]
Hint: used config file '/etc/nim/config.nims' [Conf]
....................................
Hint:  [Link]
Hint: 69200 lines; 0.747s; 94.543MiB peakmem; Debug build; proj: ~/ctf/minez_laser/mineslazer.nim; out: ~/ctf/minez_laser/mineslazer [SuccessX]

$ ./mineslazer
```

None of us has coded in Nim before, so this takes a bit of time but in the end we arrive at the
following program in [`search.nim`](res/search.nim).

```nim
## Solution for the MinezLaser Challenge
##
## Steps to victory:
##   1. Start a challenge server to attack
##   2. IMMEDIATELY after the server has started run this binary
##   3. Connect to the server and guess until you fail ONCE and get to see the full grid
##   4. Copy & Paste the grid into the terminal running this binary
##      - This tool will then search for the random seed that was used to seed the server when it
##        started.
##      - For this to work, your system time and the servers time must roughly match.
##   5. Wait until the tool is finished and prints the NEXT grid the server will work with
##   6. Either use this information to guess yourself or take the list of required commands that is
##      printed, store it in a text file (don't forget the trailing newline!) and run
##      $ nc portal.hackazon.org PORT < commands.txt

import bitops
import random
import strformat
import strutils
import times
import unidecode

# Stolen from `mileslazer.nim`
proc minesGrid(mines: uint64, steps: uint64): string =
    var grid = ""
    for y in 0..7:
        grid &= "["

        for x in 0..7:
                if steps.testBit(x+y*8):
                    grid &= "Ｄ"
                elif mines.testBit(x+y*8):
                    grid &= "Ｘ"
                else:
                    grid &= "＿"

        grid &= "]\c\L"

    return grid

# Compute a command/coordinate list with <x>,<y> tuples from a mine-vector
proc commands(mines: uint64): string =
    var commands = ""
    for y in 0..7:
        for x in 0..7:
            if mines.testBit(x + y * 8):
                commands &= fmt"{x},{y}" & "\n"
    return commands

# Parse the string representation of a grid into a mine-vector
proc reverseGrid(grid: string) : uint64 =
    var mines = uint64(0)

    var lines = splitLines(grid)
    for y in 0..7:
        var line = unidecode(lines[y])
        for x in 0..7:
            if line[x + 1] != '_':
                mines.setBit(x+y*8)

    return mines

# Read a grid from stdin
proc readGrid() : string =
    echo "Enter observed grid:"

    var grid = ""
    for x in 0..7:
        grid &= readLine(stdin) & "\c\L"
    return grid

################################################################################
# Process the first grid produced by the server
################################################################################

var grid = readGrid()
var expectedMines = reverseGrid(grid)

################################################################################
# Guess the next grid and output it
################################################################################

# Make sure we go back some some time to account for the server start window
const BACK_WINDOW = 2

# We look into the future by this much
const FRONT_WINDOW = 0

# Number of nanoseconds to iterate over (large numbers take quite a long time!)
const MAX_NANOSECONDS = convert(Seconds, Nanoseconds, BACK_WINDOW + FRONT_WINDOW)

let startSeconds = times.getTime().toUnix - BACK_WINDOW
let startNanoSeconds = convert(Seconds, Nanoseconds, startSeconds)

echo fmt"Starting search within {MAX_NANOSECONDS} ns"

var mines = uint64(0)
var found = false
for offset in 0..MAX_NANOSECONDS:
    randomize(startNanoSeconds + offset)
    mines = rand(uint64)

    if mines == expectedMines:
        found = true
        echo fmt"Result matches at {offset} ns"
        break

if not found:
    echo "No viable seed found!"
else:
    echo "Found last grid:"
    echo minesGrid(mines, uint64(0))

    echo "Expected next grid:"
    mines = rand(uint64)
    echo minesGrid(mines, uint64(0))

    echo "Commands:"
    echo commands(mines)

```

After compiling it we do the following:
```
---- web browser
Start a new server and wait until it is up

---- terminal 1
$ ./search
Enter observed grid:

---- terminal 2
$ nc portal.hackazon.org 17004
=====================
=== MINESLAZER 4000
=====================
Use the laser to remotely detonate the mines.
Make sure you don't hit any crew members with the laser though!

[?] Enter laser position: 1,1
Yikes, you hit something you weren't supposed to hit.
Hope you have good insurance, you're on your own.
[ＸＸ＿ＸＸＸ＿Ｘ]
[＿＿ＸＸＸ＿＿＿]
[＿Ｘ＿Ｘ＿Ｘ＿＿]
[＿＿＿ＸＸＸＸ＿]
[Ｘ＿＿＿＿Ｘ＿Ｘ]
[Ｘ＿ＸＸＸＸＸ＿]
[Ｘ＿ＸＸ＿＿＿＿]
[＿Ｘ＿＿ＸＸＸ＿]

---- terminal 1 (continued)
Enter observed grid:
[ＸＸ＿ＸＸＸ＿Ｘ]
[＿＿ＸＸＸ＿＿＿]
[＿Ｘ＿Ｘ＿Ｘ＿＿]
[＿＿＿ＸＸＸＸ＿]
[Ｘ＿＿＿＿Ｘ＿Ｘ]
[Ｘ＿ＸＸＸＸＸ＿]
[Ｘ＿ＸＸ＿＿＿＿]
[＿Ｘ＿＿ＸＸＸ＿]
Starting search within 2000000000 ns

---- terminal 1 (after a few minutes)
Result matches at 1174168046 ns
Found last grid:
[ＸＸＸＸＸＸ＿＿]
[ＸＸＸＸ＿＿Ｘ＿]
[＿Ｘ＿ＸＸ＿＿Ｘ]
[＿＿＿ＸＸＸ＿Ｘ]
[＿Ｘ＿ＸＸ＿Ｘ＿]
[＿＿ＸＸＸ＿＿Ｘ]
[Ｘ＿ＸＸＸＸ＿＿]
[＿ＸＸＸＸＸＸＸ]

Expected next grid:
[ＸＸＸ＿ＸＸＸ＿]
[＿＿ＸＸＸＸ＿Ｘ]
[ＸＸＸＸ＿＿＿＿]
[＿Ｘ＿ＸＸＸ＿Ｘ]
[＿＿＿＿＿＿Ｘ＿]
[＿＿＿＿Ｘ＿＿Ｘ]
[＿＿ＸＸ＿＿＿Ｘ]
[＿ＸＸＸＸＸＸＸ]

Commands:
0,0
1,0
...
5,7
6,7
7,7
```

We now have our next grid! For convenience, we have also printed the list of coordinates that we
need to enter to win the game.
We save them in a text file (`input.txt`) with a trailing newline and run:

```
$ nc portal.hackazon.org 17004 < input.txt
...
[?] Enter laser position: Pew pew pew! Bomb successfully detonated!
[ＤＤＤ＿ＤＤＤ＿]
[＿＿ＤＤＤＤ＿Ｄ]
[ＤＤＤＤ＿＿＿＿]
[＿Ｄ＿ＤＤＤ＿Ｄ]
[＿＿＿＿＿＿Ｄ＿]
[＿＿＿＿Ｄ＿＿Ｄ]
[＿＿ＤＤ＿＿＿Ｄ]
[＿ＤＤＤＤＤＤＤ]

LWOoOOohOOOO, you've gotten rid of all mines!
Here's your flag: CTF{94800bae0aa0a52d3b239ccc7a64fe49}
```

### Flag
```
CTF{94800bae0aa0a52d3b239ccc7a64fe49}
```

## Rabbit Holes
Only one major one: Unicode parsing.
For whatever reason the server does not use `X` (U+0058), `D` (U+0044), and `_` (U+005F) for the
grid. It uses `Ｘ` (U+FF38), `Ｄ` (U+FF24), and `＿` (U+FF3F).

Decoding the unicode grid input from stdin and comparing correctly probably cost the most time of
any individual part.
