//
// The MIT License (MIT)
//
// Copyright (c) 2014 BONZOO.LLC
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "BZObjectStore.h"
#import "BZObjectStoreModelInterface.h"
#import "BZObjectStoreRelationshipModel.h"
#import "BZObjectStoreAttributeModel.h"
#import "BZObjectStoreConditionModel.h"
#import "BZObjectStoreRuntime.h"
#import "BZObjectStoreRuntimeProperty.h"
#import "BZObjectStoreNameBuilder.h"
#import "FMDatabaseQueue.h"
#import "FMDatabase.h"
#import "FMResultSet.h"
#import "FMDatabaseAdditions.h"
#import "NSObject+BZObjectStore.h"

@interface BZObjectStoreReferenceMapper (Protected)
- (NSNumber*)existsObject:(NSObject*)object db:(FMDatabase*)db error:(NSError**)error;
- (NSNumber*)max:(NSString*)columnName class:(Class)clazz condition:(BZObjectStoreConditionModel*)condition  db:(FMDatabase*)db error:(NSError**)error;
- (NSNumber*)min:(NSString*)columnName class:(Class)clazz condition:(BZObjectStoreConditionModel*)condition  db:(FMDatabase*)db error:(NSError**)error;
- (NSNumber*)avg:(NSString*)columnName class:(Class)clazz condition:(BZObjectStoreConditionModel*)condition  db:(FMDatabase*)db error:(NSError**)error;
- (NSNumber*)total:(NSString*)columnName class:(Class)clazz condition:(BZObjectStoreConditionModel*)condition  db:(FMDatabase*)db error:(NSError**)error;
- (NSNumber*)sum:(NSString*)columnName class:(Class)clazz condition:(BZObjectStoreConditionModel*)condition  db:(FMDatabase*)db error:(NSError**)error;
- (NSNumber*)count:(Class)clazz condition:(BZObjectStoreConditionModel*)condition  db:(FMDatabase*)db error:(NSError**)error;
- (NSNumber*)referencedCount:(NSObject*)object db:(FMDatabase*)db error:(NSError**)error;
- (NSMutableArray*)fetchReferencingObjectsWithToObject:(NSObject*)object db:(FMDatabase*)db error:(NSError**)error;
- (NSArray*)refreshObject:(NSObject*)object db:(FMDatabase*)db error:(NSError**)error;
- (NSMutableArray*)fetchObjects:(Class)clazz condition:(BZObjectStoreConditionModel*)condition db:(FMDatabase*)db error:(NSError**)error;
- (BOOL)saveObjects:(NSArray*)objects db:(FMDatabase*)db error:(NSError**)error;
- (BOOL)removeObjects:(NSArray*)objects db:(FMDatabase*)db error:(NSError**)error;
- (BOOL)removeObjects:(Class)clazz condition:(BZObjectStoreConditionModel*)condition db:(FMDatabase*)db error:(NSError**)error;

- (BZObjectStoreRuntime*)runtime:(Class)clazz;
- (BOOL)registerRuntime:(BZObjectStoreRuntime*)runtime db:(FMDatabase*)db error:(NSError**)error;
- (BOOL)unRegisterRuntime:(BZObjectStoreRuntime*)runtime db:(FMDatabase*)db error:(NSError**)error;
- (void)setRegistedAllRuntimeFlag;
- (void)setRegistedRuntimeFlag:(BZObjectStoreRuntime*)runtime;
- (void)setUnRegistedRuntimeFlag:(BZObjectStoreRuntime*)runtime;
@end


@interface BZObjectStore ()
@property (nonatomic,weak) BZObjectStore *weakSelf;
@property (nonatomic,strong) FMDatabaseQueue *dbQueue;
@property (nonatomic,strong) FMDatabase *db;
@property (nonatomic,assign) BOOL rollback;
@end

@implementation BZObjectStore

#pragma mark constractor method

+ (instancetype)openWithPath:(NSString*)path error:(NSError**)error
{
    if (path && ![path isEqualToString:@""]) {
        if ([path isEqualToString:[path lastPathComponent]]) {
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
            NSString *dir = [paths objectAtIndex:0];
            path = [dir stringByAppendingPathComponent:path];
#ifdef DEBUG
            NSLog(@"database path = %@",path);
#endif
        }
    }
    
    FMDatabaseQueue *dbQueue = [self dbQueueWithPath:path];
    if (!dbQueue) {
        return nil;
    }
    
    BZObjectStore *os = [[self alloc]init];
    os.dbQueue = dbQueue;
    os.db = nil;
    os.weakSelf = os;
    
    NSError *err = nil;
    BOOL ret = NO;
    ret = [os registerClass:[BZObjectStoreRelationshipModel class] error:&err];
    if (!ret) {
        return nil;
    }
    ret = [os registerClass:[BZObjectStoreAttributeModel class] error:&err];
    if (!ret) {
        return nil;
    }
    if (error) {
        *error = err;
    }
    return os;
}

+ (FMDatabaseQueue*)dbQueueWithPath:(NSString*)path
{
    if (path) {
        FMDatabase *db = [FMDatabase databaseWithPath:path];
        [db open];
        [db close];
    }
    FMDatabaseQueue *dbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
    return dbQueue;
}

#pragma mark inTransaction

- (void)inTransactionWithBlock:(void(^)(FMDatabase *db,BOOL *rollback))block
{
    if (self.db) {
        if (block) {
            block(self.db,&_rollback);
        }
    } else {
        [self.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            [_weakSelf transactionDidBegin:db];
            _weakSelf.db = db;
            [db setShouldCacheStatements:YES];
            block(db,rollback);
        }];
        [self.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            [_weakSelf setRegistedAllRuntimeFlag];
        }];
        [self transactionDidEnd:self.db];
        self.db = nil;
    }
}

- (void)transactionDidBegin:(FMDatabase*)db
{
}

- (void)transactionDidEnd:(FMDatabase*)db
{
}

#pragma mark transaction

- (void)inTransaction:(void(^)(BZObjectStore *os,BOOL *rollback))block
{
    __weak BZObjectStore *weakSelf = self;
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        block(weakSelf,rollback);
    }];
}

#pragma mark exists, count, min, max methods

- (NSNumber*)existsObject:(NSObject*)object error:(NSError**)error
{
    __block NSError *err = nil;
    __block NSNumber *exists = nil;
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        exists = [_weakSelf existsObject:object db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
    }];
    if (error) {
        *error = err;
    }
    return exists;
}

- (NSNumber*)count:(Class)clazz condition:(BZObjectStoreConditionModel*)condition error:(NSError**)error
{
    __block NSError *err = nil;
    __block NSNumber *value = nil;
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        value = [_weakSelf count:clazz condition:condition db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
    }];
    if (error) {
        *error = err;
    }
    return value;
}

- (NSNumber*)max:(NSString*)columnName class:(Class)clazz condition:(BZObjectStoreConditionModel*)condition error:(NSError**)error
{
    __block NSError *err = nil;
    __block id value = nil;
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        value = [_weakSelf max:columnName class:clazz condition:condition db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
    }];
    if (error) {
        *error = err;
    }
    return value;
}

- (NSNumber*)min:(NSString*)columnName class:(Class)clazz condition:(BZObjectStoreConditionModel*)condition error:(NSError**)error
{
    __block NSError *err = nil;
    __block id value = nil;
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        value = [_weakSelf min:columnName class:clazz condition:condition db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
    }];
    if (error) {
        *error = err;
    }
    return value;
}

- (NSNumber*)total:(NSString*)columnName class:(Class)clazz condition:(BZObjectStoreConditionModel*)condition error:(NSError**)error
{
    __block NSError *err = nil;
    __block id value = nil;
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        value = [_weakSelf total:columnName class:clazz condition:condition db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
    }];
    if (error) {
        *error = err;
    }
    return value;
}

- (NSNumber*)sum:(NSString*)columnName class:(Class)clazz condition:(BZObjectStoreConditionModel*)condition error:(NSError**)error
{
    __block NSError *err = nil;
    __block id value = nil;
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        value = [_weakSelf sum:columnName class:clazz condition:condition db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
    }];
    if (error) {
        *error = err;
    }
    return value;
}

- (NSNumber*)avg:(NSString*)columnName class:(Class)clazz condition:(BZObjectStoreConditionModel*)condition error:(NSError**)error
{
    __block NSError *err = nil;
    __block id value = nil;
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        value = [_weakSelf avg:columnName class:clazz condition:condition db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
    }];
    if (error) {
        *error = err;
    }
    return value;
}


#pragma mark fetch count methods

- (NSNumber*)referencedCount:(NSObject*)object error:(NSError**)error
{
    __block NSError *err = nil;
    __block NSNumber *value = nil;
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        value = [_weakSelf referencedCount:object db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
    }];
    if (error) {
        *error = err;
    }
    return value;
}

- (NSMutableArray*)fetchReferencingObjectsTo:(NSObject*)object error:(NSError**)error
{
    __block NSError *err = nil;
    __block NSMutableArray *list = nil;
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        list = [_weakSelf fetchReferencingObjectsWithToObject:object db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
    }];
    if (error) {
        *error = err;
    }
    return list;
}


#pragma mark fetch methods

- (NSMutableArray*)fetchObjects:(Class)clazz condition:(BZObjectStoreConditionModel*)condition error:(NSError**)error
{
    __block NSError *err = nil;
    __block NSMutableArray *value = nil;
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        value = [_weakSelf fetchObjects:clazz condition:condition db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
    }];
    if (error) {
        *error = err;
    }
    return value;
}

- (id)refreshObject:(NSObject*)object error:(NSError**)error
{
    __block NSError *err = nil;
    __block NSObject *latestObject = nil;
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        latestObject = [_weakSelf refreshObject:object db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
    }];
    if (error) {
        *error = err;
    }
    return latestObject;
}



#pragma mark save methods

- (BOOL)saveObjects:(NSArray*)objects error:(NSError**)error
{
    if (![[objects class] isSubclassOfClass:[NSArray class]]) {
        return YES;
    }
    __block NSError *err = nil;
    __block BOOL ret = NO;
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        [_weakSelf saveObjects:objects db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
        return;
    }];
    if (error) {
        *error = err;
    }
    return ret;
}

- (BOOL)saveObject:(NSObject*)object error:(NSError**)error
{
    __block NSError *err = nil;
    __block BOOL ret = NO;
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        ret = [_weakSelf saveObjects:@[object] db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
    }];
    if (error) {
        *error = err;
    }
    return ret;
}

#pragma mark remove methods

- (BOOL)removeObjects:(Class)clazz condition:(BZObjectStoreConditionModel*)condition error:(NSError**)error
{
    __block NSError *err = nil;
    __block BOOL ret = NO;
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        [db setShouldCacheStatements:YES];
        ret = [_weakSelf removeObjects:clazz condition:condition db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
        return;
    }];
    if (error) {
        *error = err;
    }
    return ret;
}

- (BOOL)removeObject:(NSObject*)object error:(NSError**)error
{
    __block NSError *err = nil;
    __block BOOL ret = NO;
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        ret = [_weakSelf removeObjects:@[object] db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
        return;
    }];
    if (error) {
        *error = err;
    }
    return ret;
}

- (BOOL)removeObjects:(NSArray *)objects error:(NSError**)error
{
    if (![[objects class] isSubclassOfClass:[NSArray class]]) {
        return YES;
    }
    __block NSError *err = nil;
    __block BOOL ret = NO;
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        ret = [_weakSelf removeObjects:objects db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
    }];
    if (error) {
        *error = err;
    }
    return ret;
}

#pragma register methods

- (BOOL)registerClass:(Class)clazz error:(NSError**)error
{
    __block NSError *err = nil;
    __block BOOL ret = NO;
    __block BZObjectStoreRuntime *runtime = [self runtime:clazz];
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        ret = [_weakSelf registerRuntime:runtime db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
        return;
    }];
    [self setRegistedRuntimeFlag:runtime];
    if (error) {
        *error = err;
    }
    return ret;
}

- (BOOL)unRegisterClass:(Class)clazz error:(NSError**)error
{
    __block NSError *err = nil;
    __block BOOL ret = NO;
    __block BZObjectStoreRuntime *runtime = [self runtime:clazz];
    [self inTransactionWithBlock:^(FMDatabase *db, BOOL *rollback) {
        ret = [_weakSelf unRegisterRuntime:runtime db:db error:&err];
        if ([db hadError]) {
            err = [db lastError];
        }
        if (err) {
            *rollback = YES;
        }
        return;
    }];
    [self setUnRegistedRuntimeFlag:runtime];
    if (error) {
        *error = err;
    }
    return ret;
}

- (void)close
{
    [self.dbQueue close];
    self.dbQueue = nil;
    self.db = nil;
}


@end
