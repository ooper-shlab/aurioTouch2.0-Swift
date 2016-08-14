/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Part of CoreAudio Utility Classes
*/
#ifndef _CABitOperations_h_
#define _CABitOperations_h_

#if !defined(__COREAUDIO_USE_FLAT_INCLUDES__)
    //#include <CoreServices/../Frameworks/CarbonCore.framework/Headers/MacTypes.h>
	#include <CoreFoundation/CFBase.h>
#else
//	#include <MacTypes.h>
	#include "CFBase.h"
#endif
#include <TargetConditionals.h>

// return whether a number is a power of two
inline UInt32 IsPowerOfTwo(UInt32 x) 
{ 
	return (x & (x-1)) == 0;
}

// count the leading zeros in a word
// Metrowerks Codewarrior. powerpc native count leading zeros instruction:
// I think it's safe to remove this ...
//#define CountLeadingZeroes(x)  ((int)__cntlzw((unsigned int)x))

inline UInt32 CountLeadingZeroes(UInt32 arg)
{
// GNUC / LLVM has a builtin
#if defined(__GNUC__)
// on llvm and clang the result is defined for 0
#if (TARGET_CPU_X86 || TARGET_CPU_X86_64) && !defined(__llvm__)
	if (arg == 0) return 32;
#endif	// TARGET_CPU_X86 || TARGET_CPU_X86_64
	return __builtin_clz(arg);
#elif TARGET_OS_WIN32
	UInt32 tmp;
	__asm{
		bsr eax, arg
		mov ecx, 63
		cmovz eax, ecx
		xor eax, 31
		mov tmp, eax	// this moves the result in tmp to return.
    }
	return tmp;
#else
#error "Unsupported architecture"
#endif	// defined(__GNUC__)
}
// Alias (with different spelling)
#define CountLeadingZeros CountLeadingZeroes

inline UInt32 CountLeadingZeroesLong(UInt64 arg)
{
// GNUC / LLVM has a builtin
#if defined(__GNUC__)
#if (TARGET_CPU_X86 || TARGET_CPU_X86_64) && !defined(__llvm__)
	if (arg == 0) return 64;
#endif	// TARGET_CPU_X86 || TARGET_CPU_X86_64
	return __builtin_clzll(arg);
#elif TARGET_OS_WIN32
	UInt32 x = CountLeadingZeroes((UInt32)(arg >> 32));
	if(x < 32)
		return x;
	else
		return 32+CountLeadingZeroes((UInt32)arg);
#else
#error "Unsupported architecture"
#endif	// defined(__GNUC__)
}
#define CountLeadingZerosLong CountLeadingZeroesLong

// count trailing zeroes
inline UInt32 CountTrailingZeroes(UInt32 x)
{
	return 32 - CountLeadingZeroes(~x & (x-1));
}

// count leading ones
inline UInt32 CountLeadingOnes(UInt32 x)
{
	return CountLeadingZeroes(~x);
}

// count trailing ones
inline UInt32 CountTrailingOnes(UInt32 x)
{
	return 32 - CountLeadingZeroes(x & (~x-1));
}

// number of bits required to represent x.
inline UInt32 NumBits(UInt32 x)
{
	return 32 - CountLeadingZeroes(x);
}

// base 2 log of next power of two greater or equal to x
inline UInt32 Log2Ceil(UInt32 x)
{
	return 32 - CountLeadingZeroes(x - 1);
}

// base 2 log of next power of two less or equal to x
inline UInt32 Log2Floor(UInt32 x)
{
	return 32 - CountLeadingZeroes(x) - 1;
}

// next power of two greater or equal to x
inline UInt32 NextPowerOfTwo(UInt32 x)
{
	return 1 << Log2Ceil(x);
}

// counting the one bits in a word
inline UInt32 CountOnes(UInt32 x)
{
	// secret magic algorithm for counting bits in a word.
	UInt32 t;
	x = x - ((x >> 1) & 0x55555555);
	t = ((x >> 2) & 0x33333333);
	x = (x & 0x33333333) + t;
	x = (x + (x >> 4)) & 0x0F0F0F0F;
	x = x + (x << 8);
	x = x + (x << 16);
	return x >> 24;
}

// counting the zero bits in a word
inline UInt32 CountZeroes(UInt32 x)
{
	return CountOnes(~x);
}

// return the bit position (0..31) of the least significant bit
inline UInt32 LSBitPos(UInt32 x)
{
	return CountTrailingZeroes(x & -(SInt32)x);
}

// isolate the least significant bit
inline UInt32 LSBit(UInt32 x)
{
	return x & -(SInt32)x;
}

// return the bit position (0..31) of the most significant bit
inline UInt32 MSBitPos(UInt32 x)
{
	return 31 - CountLeadingZeroes(x);
}

// isolate the most significant bit
inline UInt32 MSBit(UInt32 x)
{
	return 1 << MSBitPos(x);
}

// Division optimized for power of 2 denominators
inline UInt32 DivInt(UInt32 numerator, UInt32 denominator)
{
	if(IsPowerOfTwo(denominator))
		return numerator >> (31 - CountLeadingZeroes(denominator));
	else
		return numerator/denominator;
}

#endif

