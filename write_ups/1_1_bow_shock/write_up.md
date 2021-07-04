# BowShock

*reversing*

## Challenge Information

> Bow shock is an amazing phenomenon, but you better not get too close...

### Additional Resources

`BowShock.jar`

## Tasks

### [50 points] BowShock

> Can you find out how to minimize bow shock and prevent everything from turning into dust?

## Solution

```
$ wget -q https://portal.hackazon.org/files/bfb155f97c39ecb22540844bd3321cfd91da8ef2/BowShock.jar
$ ls -l
total 4
-rw-r--r-- 1 vagrant vagrant 1534 Jun 28 05:27 BowShock.jar
```

Let's start by trying to run the downloaded `.jar`. Nothing bad has ever happened when downloading
and executing files of unknown purpose from the internet...

```
$ java -jar BowShock.jar
Error: LinkageError occurred while loading main class BowShock
        java.lang.UnsupportedClassVersionError: BowShock has been compiled by a more recent version of the Java Runtime (class file version 60.0), this version of the Java Runtime only recognizes class file versions up to 55.0
```

Well, we already hit a minor road block. It seems like the authors of the `BowShock.jar` application
rely on a newer Java runtime than my trusty `5.10.0-kali7-amd64` provides by default. An upgrade is
simple and I will take the safe approach and install both JRE and JDK in the newest version.

```
$ sudo apt -y install openjdk-17-jre openjdk-17-jdk
...
$ sudo update-java-alternatives --jre-headless --set /usr/lib/jvm/java-1.17.0-openjdk-amd64
$ java --version
openjdk 17-ea 2021-09-14
OpenJDK Runtime Environment (build 17-ea+19-Debian-1)
OpenJDK 64-Bit Server VM (build 17-ea+19-Debian-1, mixed mode, sharing)
```

So far, so good.

```
$ java -jar BowShock.jar
Oh damn, so much magnetosphere around here!
Set the amount of plasma to the correct amount to minimize bow shock:
```

The program seems to wait for input. I will submit a number and see what happens.

```
1
And all was dust in the wind.
```

It seems like `1` was not correct. We could continue guessing or feed the program from a list of
inputs but since we are dealing with java, decompiling the application to see what happens inside
will probably be easier.

Not every Java decompiler supports version 60.0, yet, but both [JD-GUI](https://github.com/java-decompiler/jd-gui) as
well as [IntelliJ IDEA Community Edition] should be capable of this task.
I will use IntelliJ as I have already installed it.

First, we unpack the `.jar`

```
$ unzip BowShock.jar -d extracted
Archive:  BowShock.jar
   creating: extracted/META-INF/
  inflating: extracted/META-INF/MANIFEST.MF
  inflating: extracted/BowShock.class
```

The next step is equally simple. We open the `.class` file in IntelliJ and immediately are presented
with a perfectly readable source-code representation of the program.

```java
//
// Source code recreated from a .class file by IntelliJ IDEA
// (powered by FernFlower decompiler)
//

import java.util.InputMismatchException;
import java.util.Scanner;

class BowShock {
    public static int totalInput;

    BowShock() {
    }

    public static int getInput() {
        System.out.println("Set the amount of plasma to the correct amount to minimize bow shock: ");
        Scanner var0 = new Scanner(System.in);

        int var1;
        while(true) {
            try {
                var1 = var0.nextInt();
                break;
            } catch (InputMismatchException var3) {
                System.out.print("Invalid input. Please reenter: ");
                var0.nextLine();
            }
        }

        totalInput += var1;
        return var1;
    }

    public static void bowShock() {
        System.out.println("And all was dust in the wind.");
        System.exit(-99);
    }

    public static void main(String[] var0) {
        System.out.println("Oh damn, so much magnetosphere around here!");
        if (getInput() != 333) {
            bowShock();
        }

        System.out.println("We survive another day!");
        if (getInput() != 942) {
            bowShock();
        }

        if (getInput() != 142) {
            bowShock();
        }

        System.out.println("Victory!");
        System.out.println("CTF{bowsh0ckd_" + totalInput + "}");
    }
}

```

The `main()` function gives everything away. Reading the rest of the source code we could just
compute the flag ourselves, but someone obviously put in the logic to be executed and we will do
them the favor.

```
$ java -jar BowShock.jar
Oh damn, so much magnetosphere around here!
Set the amount of plasma to the correct amount to minimize bow shock: 
333
We survive another day!
Set the amount of plasma to the correct amount to minimize bow shock: 
942
Set the amount of plasma to the correct amount to minimize bow shock: 
142
Victory!
CTF{bowsh0ckd_1417}
```

### Flag
```
CTF{bowsh0ckd_1417}
```

## Rabbit Holes
This challenge was again rather easy. Most time went into installing a newer Java version and
looking up suitable decompilers.

Judging by the comment at the top of the decompiled Java code, IntelliJ's integrated decompiler is
called *FernFlower* ([more information on GitHub](https://github.com/JetBrains/intellij-community/tree/master/plugins/java-decompiler/engine))
so let us test if we can just run that instead of the while IntelliJ GUI.

```
$ find idea-IC-211.7628.21/ -name "*decompiler*.jar"
idea-IC-211.7628.21/plugins/java-decompiler/lib/java-decompiler.jar
```

Alright, it seems like it is shipped with the IDE as a standalone `.jar`.

```
$ mkdir -p decompiled
$ java -cp idea-IC-211.7628.21/plugins/java-decompiler/lib/java-decompiler.jar \
    org.jetbrains.java.decompiler.main.decompiler.ConsoleDecompiler \
    extracted/BowShock.class decompiled/
INFO:  Decompiling class BowShock
INFO:  ... done
$ ls -l decompiled/
total 4
-rw-r--r-- 1 vagrant vagrant 1203 Jul  4 16:27 BowShock.java
```

Perfect, so no need to ever use a GUI in the future ;-)

