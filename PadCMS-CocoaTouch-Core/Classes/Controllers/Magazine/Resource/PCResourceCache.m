//
//  Copyright (c) PadCMS (http://www.padcms.net)
//
//
//  This software is governed by the CeCILL-C  license under French law and
//  abiding by the rules of distribution of free software.  You can  use,
//  modify and/ or redistribute the software under the terms of the CeCILL-C
//  license as circulated by CEA, CNRS and INRIA at the following URL
//  "http://www.cecill.info".
//  
//  As a counterpart to the access to the source code and  rights to copy,
//  modify and redistribute granted by the license, users are provided only
//  with a limited warranty  and the software's author,  the holder of the
//  economic rights,  and the successive licensors  have only  limited
//  liability.
//  
//  In this respect, the user's attention is drawn to the risks associated
//  with loading,  using,  modifying and/or developing or reproducing the
//  software by the user in light of its specific status of free software,
//  that may mean  that it is complicated to manipulate,  and  that  also
//  therefore means  that it is reserved for developers  and  experienced
//  professionals having in-depth computer knowledge. Users are therefore
//  encouraged to load and test the software's suitability as regards their
//  requirements in conditions enabling the security of their systems and/or
//  data to be ensured and,  more generally, to use and operate it in the
//  same conditions as regards security.
//  
//  The fact that you are presently reading this means that you have had
//  knowledge of the CeCILL-C license and that you accept its terms.
//

#import "PCResourceCache.h"
#import "PCResourceQueue.h"
#import "PCResourceFetch.h"
#import "PCResourceView.h"

@implementation PCResourceCache

#pragma mark Constants

#define CACHE_SIZE (30 * 1024 * 1024)

//#pragma mark Properties

//@synthesize ;

#pragma mark PCResourceCache class methods

+ (PCResourceCache *)sharedInstance
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	static dispatch_once_t predicate = 0;

	static PCResourceCache *object = nil; // Object

	dispatch_once(&predicate, ^{ object = [[self alloc] init]; });

	return object; // PCResourceCache singleton
}

#pragma mark PCResourceCache instance methods

- (id)init
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	if ((self = [super init])) // Initialize
	{
		resourceCache = [[NSCache alloc] init]; // Cache

		[resourceCache setName:@"PCResourceCache"];

		[resourceCache setTotalCostLimit:CACHE_SIZE];
        
        //[resourceCache setEvictsObjectsWithDiscardedContent:YES];
        
        //[resourceCache setDelegate:self];
	}

	return self;
}

- (void)cache:(NSCache *)cache willEvictObject:(id)obj
{
#ifdef DEBUGX
    NSLog(@"%s", __FUNCTION__);
    
    NSLog(@"object = %@", obj);
#endif
}

- (void)dealloc
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	[resourceCache release], resourceCache = nil;

	[super dealloc];
}

- (id)resourceLoadBadQualityRequest:(PCResourceLoadRequest *)request
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif
    
    if(request.fileBadQualityURL == nil)
    {
        return [self resourceLoadGoodQualityRequest:request];
    }
    else
    {
        @synchronized(resourceCache) // Mutex lock
        {
            id object = [resourceCache objectForKey:request.fileURL];
            
            if (object == nil) // Resource object does not yet exist in the cache
            {
                object = [resourceCache objectForKey:request.fileBadQualityURL];
                
                if (object == nil)
                {
                    object = [NSNull null]; // Return an NSNull placeholder object
                    
                    [resourceCache setObject:object forKey:request.fileBadQualityURL cost:2]; // Cache the placeholder object
                    
                    // Create a resource fetch operation
                    PCResourceFetch *resourceFetch = [[PCResourceFetch alloc] initWithRequest:request];
                    
                    resourceFetch.isBadQuality = YES;
                    
                    [resourceFetch setQueuePriority:NSOperationQueuePriorityNormal]; // Queue priority
                    
                    request.resourceView.operation = resourceFetch; [resourceFetch setThreadPriority:0.55]; // Thread priority
                    
                    [[PCResourceQueue sharedInstance] addLoadOperation:resourceFetch]; [resourceFetch release]; // Queue the operation
                }
                else
                {
                    [self resourceLoadGoodQualityRequest:request];
                }
            }
            
            return object; // NSNull or UIImage
        }
    }
}

- (id)resourceLoadGoodQualityRequest:(PCResourceLoadRequest *)request
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif
    
    @synchronized(resourceCache) // Mutex lock
    {
        id object = [resourceCache objectForKey:request.fileURL];
        
        if (object == nil) // Resource object does not yet exist in the cache
        {
            object = [NSNull null]; // Return an NSNull placeholder object
            
            [resourceCache setObject:object forKey:request.fileURL cost:2]; // Cache the placeholder object
            
            // Create a resource fetch operation
            PCResourceFetch *resourceFetch = [[PCResourceFetch alloc] initWithRequest:request];
            
            [resourceFetch setQueuePriority:NSOperationQueuePriorityLow]; // Queue priority
            
            request.resourceView.operation = resourceFetch; [resourceFetch setThreadPriority:0.35]; // Thread priority
            
            [[PCResourceQueue sharedInstance] addLoadOperation:resourceFetch]; [resourceFetch release]; // Queue the operation
        }
        
        return object; // NSNull or UIImage
    }
}

- (id)resourceLoadRequestImmediate:(PCResourceLoadRequest *)request
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif
    
	@synchronized(resourceCache) // Mutex lock
	{
        [self removeNullForKey:request.fileURL];
        
		id object = [resourceCache objectForKey:request.fileURL];
        
		if (object == nil) // Resource object does not yet exist in the cache
		{
            if(![[PCResourceQueue sharedInstance] cancelNotStartedOperationWithObject:request.resourceView])
            {
                return object;
            }
            
            // Create a resource fetch operation
            PCResourceFetch *resourceFetch = [[PCResourceFetch alloc] initWithRequest:request];
            
            [resourceFetch main];
            
            [resourceFetch release];
		}
        
		return object; // NSNull or UIImage
	}
}

- (void)setObject:(UIImage *)image forKey:(NSString *)key
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	@synchronized(resourceCache) // Mutex lock
	{
		NSUInteger bytes = (image.size.width * image.size.height * 4.0f);

		[resourceCache setObject:image forKey:key cost:bytes]; // Cache image
	}
}

- (void)removeObjectForKey:(NSString *)key
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	@synchronized(resourceCache) // Mutex lock
	{
		[resourceCache removeObjectForKey:key];
	}
}

- (void)removeNullForKey:(NSString *)key
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	@synchronized(resourceCache) // Mutex lock
	{
		id object = [resourceCache objectForKey:key];

		if ([object isMemberOfClass:[NSNull class]])
		{
			[resourceCache removeObjectForKey:key];
		}
	}
}

- (void)removeAllObjects
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	@synchronized(resourceCache) // Mutex lock
	{
		[resourceCache removeAllObjects];
	}
}

@end
