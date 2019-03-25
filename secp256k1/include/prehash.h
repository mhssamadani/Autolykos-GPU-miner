#ifndef PREHASH_H
#define PREHASH_H

/*******************************************************************************

    PREHASH -- precalculation of hashes

********************************************************************************

initPrehash 
    in:     array 'data' contains (pk || mes || w || padding || x || sk)

    out:    computes array 'hash' of N uint256_t elements:
            hash[j] := blake2b-256(j || M || pk || mes || w) 

    out:    computes array 'invalid' of N uint32_t elements:
            invalid[j] := (hash[j] < 15 * Q)? 0: j + 1 

********************************************************************************

unfinalInitPrehash
    in:     array 'data' contains pk

    out:    computes an array 'uctx' of N blake2b_ctx elements:
            uctx[j] := unfinalized hash context for blake2b-256(j || M || pk)

********************************************************************************

updatePrehash
    in:     array 'hash' of N uint256_t elements:
            hash[j] == blake2b-256(j || M || pk || mes || w) 

    in:     array 'invalid' of 'len' uint32_t nonzero elements:
            invalid == { i : hash[i - 1] >= 15 * Q }

    in:     constant 'len':
            length of 'invalid'

    alt:    for each i in 'invalid':
            hash[i - 1] := blake2b-256(hash[i - 1])

    alt:    for each i in 'invalid':
            invalid[i - 1] := (hash[i - 1] < 15 * Q)? 0: i

********************************************************************************

finalPrehash
    in:     array 'data' contains (pk || mes || w || padding || x || sk)

    in:     array 'hash' of N uint256_t elements:
            hash[j] == H(j || M || pk || mes || w) 

    alt:    for each j:
            hash[j] := hash[j] * x mod Q

********************************************************************************

*******************************************************************************/

#include "definitions.h"

// first iteration of hashes precalculation
__global__ void InitPrehash(
    // data: pk || mes || w || padding || x || sk
    const uint32_t * data,
    // hashes
    uint32_t * hash,
    // indices of invalid range hashes
    uint32_t * invalid
);

// unfinalized first iteration of hashes precalculation
__global__ void UnfinalInitPrehash(
    // data: pk
    const uint32_t * data,
    // unfinalized hash contexts
    blake2b_ctx * uctx
);

// unfinalized hashes update
__global__ void UpdatePrehash(
    // hashes
    uint32_t * hash,
    // indices of invalid range hashes
    uint32_t * invalid,
    // length of invalid
    const uint32_t len
);

// hashes modulo Q 
__global__ void FinalPrehash(
    // hashes
    uint32_t * hash
);

// hashes by secret key multiplication modulo Q 
__global__ void FinalPrehashMultSecKey(
    // data: pk || mes || w || padding || x || sk
    const uint32_t * data,
    // hashes
    uint32_t * hash
);

// precalculate hashes
int Prehash(
    // data: pk || mes || w || padding || x || sk
    const uint32_t * data,
    // hashes
    uint32_t * hash,
    // indices of invalid range hashes
    uint32_t * invalid
);

#endif // PREHASH_H