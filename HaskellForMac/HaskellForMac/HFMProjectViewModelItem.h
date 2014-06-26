//
//  HFMProjectViewModelItem.h
//  HaskellForMac
//
//  Created by Manuel M T Chakravarty on 13/06/2014.
//  Copyright (c) 2014 Manuel M T Chakravarty. All rights reserved.
//
//  This class provides a view model representation of the individual items that are displayed in the project's outline
//  view. Following the requirements of 'NSOutlineView', each view model item is only used to represent a single item
//  in the outline view.

#import <Foundation/Foundation.h>
#import "HFMProjectViewModel.h"


/// Tag determining which of several flavours of project view model items we have.
//
typedef NS_ENUM(NSUInteger, PVMItemTag) {
  PVMItemTagGroup,            // Toplevel group in the outline view
  PVMItemTagPackage,          // Identifies the Cabal packages itself
  PVMItemTagExecutable,       // Executable secion of the Cabal package
  PVMItemTagFileGroup,        // Logical collection of files (wildcard name or source directory or data directory)
  PVMItemTagFolder,           // File system directory
  PVMItemTagFile,             // Concrete file that is part of the package
};

/// Outline view group ids
//
extern NSString *const kPackageGroupID;
extern NSString *const kDataGroupID;
extern NSString *const kExecutableGroupID;
extern NSString *const kExtraSourceGroupID;


@interface HFMProjectViewModelItem : NSObject

/// Determines which flavour of project view model item this is.
//
@property (readonly) PVMItemTag tag;

/// Identifier that is used to display the item.
//
@property (nonatomic) NSString *identifier;

/// File wrapper of the file object backing the item.
///
/// This property is computed lazily.
///
/// The reference is weak as the file wrapper object is owned by either its parent directory wrapper or, if it is the
/// document file wrapper, by the view model object.
//
@property (nonatomic, readonly, weak) NSFileWrapper *fileWrapper;

/// Does this item have unsaved changes?
//
@property (readonly) BOOL dirty;


#pragma mark -
#pragma mark Initialisation

/// Create a new item of a given flavour with an identifier that is used to display the item.
//
+ (instancetype)projectViewModelItemWithGroup:(PVMItemTag)tag
                                   identifier:(NSString *)identifier
                                       parent:(HFMProjectViewModelItem *)parent
                                        model:(HFMProjectViewModel *)model;

/// Initialise a new item of a given flavour with an identifier that is used to display the item.
//
- (instancetype)initWithGroup:(PVMItemTag)tag
                   identifier:(NSString *)identifier
                       parent:(HFMProjectViewModelItem *)parent
                        model:(HFMProjectViewModel *)model;


#pragma mark -
#pragma mark Mutatation

/// Replace the data represented by this item with the argument.
//
- (void)updateItemWithData:(NSData *)data;


#pragma mark -
#pragma mark Queries

/// Returns an array containing all child items of the current item.
//
- (NSArray/*<HFMProjectModelItem>*/ *)children;

/// Returns the item's file name relative to the document root.
//
- (NSString *)fileName;

/// Returns an updated file wrapper in case this item is 'dirty'; otherwise, returns 'nil'.
///
/// After this method was invoked, the item is not dirty (until the next change) — i.e., discarding the returned
/// file wrapper will discard any changes since the last save.
//
- (NSFileWrapper *)getUpdatedFileWrapper;

@end
