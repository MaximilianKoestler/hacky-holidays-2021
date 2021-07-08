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

################################################################################
# Setup timing at the beginning
################################################################################

# Make sure we go back some some time to account for the server start window
const BACK_WINDOW = 2

# We look into the future by this much
const FRONT_WINDOW = 0

# Number of nanoseconds to iterate over (large numbers take quite a long time!)
const MAX_NANOSECONDS = convert(Seconds, Nanoseconds, BACK_WINDOW + FRONT_WINDOW)

let startSeconds = times.getTime().toUnix - BACK_WINDOW
let startNanoSeconds = convert(Seconds, Nanoseconds, startSeconds)

################################################################################
# Utilities for mines and grids
################################################################################

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
