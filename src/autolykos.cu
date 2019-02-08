// autolykos.cu

#include "../include/prehash.h"
#include "../include/validation.h"
#include "../include/reduction.h"
#include "../include/compaction.h"
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <cuda.h>
#include <curand.h>

////////////////////////////////////////////////////////////////////////////////
//  Main cycle
////////////////////////////////////////////////////////////////////////////////
int main(int argc, char ** argv)
{
    //====================================================================//
    //  Host memory
    //====================================================================//
    uint32_t ind = 1;

    // BLAKE_2B_256 params
    // 64 bytes
    const uint64_t blake2b_iv[8] = {
        0x6A09E667F3BCC908, 0xBB67AE8584CAA73B,
        0x3C6EF372FE94F82B, 0xA54FF53A5F1D36F1,
        0x510E527FADE682D1, 0x9B05688C2B3E6C1F,
        0x1F83D9ABFB41BD6B, 0x5BE0CD19137E2179
    };

    // pemutations of {0, 1, ..., 15}
    // 192 bytes
    const uint8_t sigma[192] = {
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
        14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3,
        11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4,
        7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8,
        9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13,
        2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9,
        12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11,
        13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10,
        6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5,
        10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0,
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
        14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3
    };

    // 212 bytes
    blake2b_ctx ctx_h;

    // 8 * 32 bits = 32 bytes
    uint32_t mes_h[8] = {0, 0, 0, 0, 0, 0, 0, 0}; 

    // L_LEN * 256 bits
    uint32_t * res_h = (uint32_t *)malloc(L_LEN * 8 * 4); 

    //====================================================================//
    // secret key
    //>>>genSKey();
    uint32_t sk_h[8] = {0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 1, 2}; 

    // public key
    //>>>genPKey();
    uint32_t pk_h[8] = {0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 3, 4}; 

    // one time secret key
    //>>>genSKey();
    uint32_t x_h[8] = {0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 5, 6}; 

    // one time public key
    //>>>genPKey();
    uint32_t w_h[8] = {0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 7, 8}; 

    //====================================================================//
    //  Device memory
    //====================================================================//
    // nonces
    // H_LEN * L_LEN * 4 bytes // 64 MB
    uint32_t * non_d;
    CUDA_CALL(cudaMalloc((void **)&non_d, H_LEN * L_LEN * 4));

    // data: blake2b_iv || sigma || sk || pk || mes || w || x
    // (256 + 5 * NUM_BYTE_SIZE) bytes // ~0 MB
    uint32_t * data_d;
    CUDA_CALL(cudaMalloc((void **)&data_d, 256 + 5 * NUM_BYTE_SIZE));

    // precalculated hashes
    // N_LEN * NUM_BYTE_SIZE bytes // 2 GB
    uint32_t * hash_d;
    CUDA_CALL(cudaMalloc((void **)&hash_d, (uint32_t)N_LEN * NUM_BYTE_SIZE));

    // indices of unfinalized hashes
    // H_LEN * N_LEN * 4 bytes // 256 MB
    uint32_t * unfinalized_d;
    CUDA_CALL(cudaMalloc((void **)&unfinalized_d, (uint32_t)8 * H_LEN * N_LEN));

    // potential solutions of puzzle
    // H_LEN * N_LEN * 4 bytes // 256 MB
    uint32_t * res_d;
    CUDA_CALL(cudaMalloc((void **)&res_d, H_LEN * N_LEN * 4));

    //====================================================================//
    //  Random generator initialization
    //====================================================================//
    curandGenerator_t gen;
    CURAND_CALL(curandCreateGenerator(&gen, CURAND_RNG_PSEUDO_MTGP32));
    
    time_t rawtime;
    // get current time (ms)
    time(&rawtime);

    // set seed
    CURAND_CALL(curandSetPseudoRandomGeneratorSeed(gen, (uint64_t)rawtime));

    //====================================================================//
    //  Memory: Host -> Device
    //====================================================================//
    CUDA_CALL(cudaMemcpy(
        (void *)data_d, (void *)blake2b_iv, 64, cudaMemcpyHostToDevice
    ));
    CUDA_CALL(cudaMemcpy(
        (void *)(data_d + 16), (void *)sigma, 192, cudaMemcpyHostToDevice
    ));
    CUDA_CALL(cudaMemcpy(
        (void *)(data_d + 64), (void *)sk_h, NUM_BYTE_SIZE,
        cudaMemcpyHostToDevice
    ));
    CUDA_CALL(cudaMemcpy(
        (void *)(data_d + 64 + (NUM_BYTE_SIZE >> 2)), (void *)pk_h,
        NUM_BYTE_SIZE, cudaMemcpyHostToDevice
    ));
    CUDA_CALL(cudaMemcpy(
        (void *)(data_d + 64 + 2 * (NUM_BYTE_SIZE >> 2)), (void *)mes_h,
        NUM_BYTE_SIZE, cudaMemcpyHostToDevice
    ));
    CUDA_CALL(cudaMemcpy(
        (void *)(data_d + 64 + 4 * (NUM_BYTE_SIZE >> 2)), (void *)x_h,
        NUM_BYTE_SIZE, cudaMemcpyHostToDevice
    ));
    CUDA_CALL(cudaMemcpy(
        (void *)(data_d + 64 + 3 * (NUM_BYTE_SIZE >> 2)), (void *)w_h,
        NUM_BYTE_SIZE, cudaMemcpyHostToDevice
    ));

    //====================================================================//
    //  Autolykos puzzle cycle
    //====================================================================//
    struct timeval t1, t2;

    while (ind) //>>>(1)
    {
        gettimeofday(&t1, 0);

        // on obtaining solution
        if (ind == 1)
        {
            //>>>genSKey();
            CUDA_CALL(cudaMemcpy(
                (void *)(data_d + 64 + 4 * (NUM_BYTE_SIZE >> 2)), (void *)x_h,
                NUM_BYTE_SIZE, cudaMemcpyHostToDevice
            ));
            //>>>genPKey();
            CUDA_CALL(cudaMemcpy(
                (void *)(data_d + 64 + 3 * (NUM_BYTE_SIZE >> 2)), (void *)w_h,
                NUM_BYTE_SIZE, cudaMemcpyHostToDevice
            ));

            prehash(data_d, hash_d, unfinalized_d);
        }

        cudaThreadSynchronize();
        gettimeofday(&t2, 0);

        /// // generate nonces
        /// CURAND_CALL(curandGenerate(gen, non_d, 4 * L_LEN * H_LEN));

        /// // calculate unfinalized hash of message
        /// initMining(&ctx_h, sk_h, mes_h, NUM_BYTE_SIZE);

        /// // context: host -> device
        /// CUDA_CALL(cudaMemcpy(
        ///     (void *)(data_d + 5 * (NUM_BYTE_SIZE >> 2)),
        ///     (void *)&ctx_h, sizeof(blake2b_ctx), cudaMemcpyHostToDevice
        /// ));

        /// // calculate hashes
        /// blockMining<<<G_DIM, B_DIM>>>(
        ///     data_d, non_d, hash_d, res_d, unfinalized_d
        /// );

        // try to find solution
        // ind = findNonZero(unfinalized_d, unfinalized_d + H_LEN * N_LEN * 4);
        ind = 0;
    }

    double time
        = (1000000. * (t2.tv_sec - t1.tv_sec) + t2.tv_usec - t1.tv_usec)
        / 1000000.0;

    printf("Time to generate:  %.5f s \n", time);

    //====================================================================//
    //  Free device memory
    //====================================================================//
    CURAND_CALL(curandDestroyGenerator(gen));
    CUDA_CALL(cudaFree(non_d));
    CUDA_CALL(cudaFree(hash_d));
    CUDA_CALL(cudaFree(data_d));
    CUDA_CALL(cudaFree(unfinalized_d));
    CUDA_CALL(cudaFree(res_d));

    return 0;
}

// autolykos.cu