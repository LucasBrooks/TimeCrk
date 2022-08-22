# TimeCrk
Windows 95/Memphis Generic Timebomb Killer v1.0 from 27 May 1996 by tHE riDDLER 1996.

The good old Windows 9x debomb tool by tHE riDDLER 1996. Posting the full disassembly and unprotected version here because it is the only available Windows 9x debomb tool and well, it's obfuscated. You see, if you didn't put 2 layers of obfuscation there I wouldn't even attempt to reverse it, the more you protect your code the more it makes people want to see what's happening.

## Unprotect
Like most obfuscated DOS executables, it makes IDA think that it was packed, I tried all DOS unpackers I have and none of them worked. While it is a huge pain to unprotect with static analysis, it's not that hard to unobfuscate with a debugger, just set a break point and dump the memory - simple. Biggest problem is the relocations are lost so you'll need to manually go through the code and patch all the offsets references.

## Code
This is a full disassembly, but not done yet. Comments are there but they're all over the place. It will not assemble back because of the `LARGE` keyword, and I don't know how to make MASM produce 16-bit code with 32-bit memory references. Maybe it was assembled by a different or even custom assembler. Anyway the code is pretty understandable and good enough if you just want to know how it works to be able to write your own patcher.
