/*
 * Copyright (C) 2018 Advanced Card Systems Ltd. All rights reserved.
 *
 * This software is the confidential and proprietary information of Advanced
 * Card Systems Ltd. ("Confidential Information").  You shall not disclose such
 * Confidential Information and shall use it only in accordance with the terms
 * of the license agreement you entered into with ACS.
 */

#import <Foundation/Foundation.h>

/**
 * The Crypto class provides the AES encryption and decryption routines.
 *
 * @author  Godfrey Chung
 * @version 1.0
 * @date    3 Jul 2018
 * @since   0.3.1
 */
@interface Crypto : NSObject

/**
 * Encrypts the data using AES128.
 *
 * @param key           the key
 * @param keyLength     the key length
 * @param dataIn        the input buffer
 * @param dataInOffset  the input buffer offset
 * @param dataInLength  the input buffer length
 * @param dataOut       the output buffer
 * @param dataOutOffset the output buffer offset
 * @param dataOutLength the output buffer length
 * @param bytesReturned the pointer to the number of bytes returned
 * @return the error code
 */
+ (int32_t)aesEncrypt:(const void *)key
            keyLength:(size_t)keyLength
               dataIn:(const void *)dataIn
         dataInOffset:(size_t)dataInOffset
         dataInLength:(size_t)dataInLength
              dataOut:(void *)dataOut
        dataOutOffset:(size_t)dataOutOffset
        dataOutLength:(size_t)dataOutLength
        bytesReturned:(size_t *)bytesReturned;

/**
 * Decrypts the data using AES128.
 *
 * @param key           the key
 * @param keyLength     the key length
 * @param dataIn        the input buffer
 * @param dataInOffset  the input buffer offset
 * @param dataInLength  the input buffer length
 * @param dataOut       the output buffer
 * @param dataOutOffset the output buffer offset
 * @param dataOutLength the output buffer length
 * @param bytesReturned the pointer to the number of bytes returned
 * @return the error code
 */
+ (int32_t)aesDecrypt:(const void *)key
            keyLength:(size_t)keyLength
               dataIn:(const void *)dataIn
         dataInOffset:(size_t)dataInOffset
         dataInLength:(size_t)dataInLength
              dataOut:(void *)dataOut
        dataOutOffset:(size_t)dataOutOffset
        dataOutLength:(size_t)dataOutLength
        bytesReturned:(size_t *)bytesReturned;

@end
