//
// Copyright 2016 Mobile Jazz SL
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "NSError+BlueFish.h"

@implementation NSError (BlueFish)

+ (NSError *)bf_createErrorWithDomain:(NSString *)domain
                                 code:(NSInteger)code
                          description:(NSString *)description
{
    NSDictionary *userInfo = description ? @{ NSLocalizedDescriptionKey : description } : nil;
    return [NSError errorWithDomain:domain code:code userInfo:userInfo];
}

+ (NSError *)bf_createErrorWithDomain:(NSString *)domain
                                 code:(NSInteger)code
                          description:(NSString *)description
                        originalError:(NSString *)originalError
{
    NSMutableDictionary *userinfo = [NSMutableDictionary dictionary];
    if (description)
    {
        [userinfo setObject:description forKey:NSLocalizedDescriptionKey];
    }
    
    if (originalError)
    {
        [userinfo setObject:originalError forKey:@"originalError"];
    }
    return [NSError errorWithDomain:domain code:code userInfo:userinfo];
}

@end
