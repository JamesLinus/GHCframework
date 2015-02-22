//
//  HFMProjectViewModel.m
//  HaskellForMac
//
//  Created by Manuel M T Chakravarty on 7/02/2014.
//  Copyright (c) 2014 Manuel M T Chakravarty. All rights reserved.
//

#import "Haskell-Swift.h"
#import "CabalKit/CabalKit.h"
#import "HFMProjectViewModel.h"


@interface HFMProjectViewModel ()

// The Cabal package describing the project. 'CBLPackage' objects are immutable — i.e., whenever package data changes,
// this property will be updated.
//
// This is our interface to the Haskell-side data model.
//
@property CBLPackage *package;

@end


// Function prototypes
//
NSDictionary *stringsToDictTree(NSArray      *strings);
NSArray      *dictTreeToStrings(NSDictionary *dicts);
NSDictionary *itemsToDictTree(NSArray *items, BOOL asSourceModules);


@implementation HFMProjectViewModel

@synthesize identifier = _identifier;


#pragma mark -
#pragma mark Informative class methods

static NSString *cabalFileExtension = @"cabal";
+ (NSString *)cabalFileExtension
{
  return cabalFileExtension;
}

static NSString *haskellFileExtension = @"hs";
+ (NSString *)haskellFileExtension
{
  return haskellFileExtension;
}

static NSString *haskellPlaygroundFileExtension = @"hsplay";
+ (NSString *)haskellPlaygroundFileExtension
{
  return haskellPlaygroundFileExtension;
}



#pragma mark -
#pragma mark Initialisation

+ (instancetype)projectViewModelWithProjectFileWrapper:(NSFileWrapper *)projectFileWrapper
                                      cabalFileWrapper:(NSFileWrapper *)cabalFileWrapper
                                           documentURL:(NSURL *)documentURL
{
  return [[HFMProjectViewModel alloc] initWithProjectFileWrapper:projectFileWrapper
                                                cabalFileWrapper:cabalFileWrapper
                                                     documentURL:documentURL];
}

- (instancetype)init
{
  NSLog(@"%s: cannot initialise the view model without a name for the Cabal file", __func__);
  return nil;
}

- (instancetype)initWithProjectFileWrapper:(NSFileWrapper *)projectFileWrapper
                          cabalFileWrapper:(NSFileWrapper *)cabalFileWrapper
                               documentURL:(NSURL *)documentURL
{
  self = [super init];
  if (self) {

    _fileWrapper = projectFileWrapper;

      // If no Cabal file present, create a new, empty Cabal package whose name is derived from the package name and add
      // it to the file wrapper for the project.
    if (!cabalFileWrapper) {

        // Create a new empty package description.
      _package = [CBLPackage package];

        // Wrap it into a new file wrapper.
      NSString *fname = [[[projectFileWrapper preferredFilename] stringByDeletingPathExtension]
                         stringByAppendingPathExtension:cabalFileExtension];
      NSData   *data  = [[self.package string] dataUsingEncoding:NSUTF8StringEncoding];
      [projectFileWrapper addRegularFileWithContents:data preferredFilename:fname];
      cabalFileWrapper = [projectFileWrapper fileWrappers][fname];
      
    } else {
    
      NSString *cabalContents = [[NSString alloc] initWithData:[cabalFileWrapper regularFileContents]
                                                      encoding:NSUTF8StringEncoding];

      _package = [CBLPackage packageWithString:cabalContents];
      if (!_package) return nil;    // Bail out if we cannot load the Cabal file

    }
    _cabalFileName = cabalFileWrapper.preferredFilename;
    _documentURL   = documentURL;

      // Set up the group items
    _groupItems = [[ProjectItemGroups alloc] initWithViewModel:self];
  }
  return self;
}

- (void)createProjectForURL:(NSURL *)url
{
  NSString *path         = [url path];
  NSString *projname     = [path lastPathComponent];
  NSString *name         = [projname stringByDeletingPathExtension];
  NSString *mainName     = [name stringByAppendingPathExtension:[HFMProjectViewModel haskellFileExtension]];
  NSString *oldCabalName = [self.cabalFileName lastPathComponent];
  NSString *newCabalName = [name stringByAppendingPathExtension:[HFMProjectViewModel cabalFileExtension]];

    // The URL is where we want to save the project and we need to change the cached Cabal filename, too.
  self.fileWrapper.preferredFilename = projname;
  _cabalFileName                     = newCabalName;

    // Configure basic Cabal fields.
  self.name           = name;
  self.version        = @"1.0";
  self.license        = @"AllRightsReserved";
  self.executableName = name;
  self.sourceDir      = nil;
  self.modules        = @{mainName : @{} };

    // Create a new file wrapper for the new Cabal file.
  [self.fileWrapper removeFileWrapper:[self.fileWrapper fileWrappers][oldCabalName]];
  [self.fileWrapper addRegularFileWithContents:[[self.package string] dataUsingEncoding:NSUTF8StringEncoding]
                             preferredFilename:newCabalName];

    // Create main Haskell file
  [self.fileWrapper addRegularFileWithContents:[NSData data] preferredFilename:mainName];

    // Write new project out and create the group items.
  NSError *error;
  if (![self.fileWrapper writeToURL:url
                            options:NSFileWrapperWritingWithNameUpdating
                originalContentsURL:nil
                              error:&error])
    NSLog(@"%s: couldn't create project files: %@", __func__, error);
  _groupItems = [[ProjectItemGroups alloc] initWithViewModel:self];
}


#pragma mark -
#pragma mark Setters and getters

- (NSString *)identifier
{
  if (!_identifier) _identifier = [self.package identifier];
  return _identifier;
}

- (void)setName:(NSString *)name
{
  self.package = [CBLPackage package:self.package withName:name];
  NSLog(@"Update project name");
}

- (NSString *)name
{
  return self.package.name;
}

- (void)setVersion:(NSString *)version
{
  self.package = [CBLPackage package:self.package withVersion:version];
  NSLog(@"Update project version");
}

- (NSString *)version
{
  return self.package.version;
}

- (void)setCategory:(NSString *)category
{
  self.package = [CBLPackage package:self.package withCategory:category];
  NSLog(@"Update project category");
}

- (NSString *)category
{
  return self.package.category;
}

- (void)setSynopsis:(NSString *)synopsis
{
  self.package = [CBLPackage package:self.package withSynopsis:synopsis];
  NSLog(@"Update project synopsis");
}

- (NSString *)synopsis
{
  return self.package.synopsis;
}

- (void)setFullDescription:(NSString *)fullDescription
{
  self.package = [CBLPackage package:self.package withFullDescription:fullDescription];
  NSLog(@"Update project description");
}

- (NSString *)fullDescription
{
  return self.package.fullDescription;
}

- (void)setAuthor:(NSString *)author
{
  self.package = [CBLPackage package:self.package withFullDescription:author];
  NSLog(@"Update project author");
}

- (NSString *)author
{
  return self.package.author;
}

- (void)setMaintainer:(NSString *)maintainer
{
  self.package = [CBLPackage package:self.package withMaintainer:maintainer];
  NSLog(@"Update project maintainer");
}

- (NSString *)maintainer
{
  return self.package.maintainer;
}

- (void)setCopyright:(NSString *)copyright
{
  self.package = [CBLPackage package:self.package withCopyright:copyright];
  NSLog(@"Update project copyright");
}

- (NSString *)copyright
{
  return self.package.copyright;
}

- (void)setLicense:(NSString *)license
{
  self.package = [CBLPackage package:self.package withLicense:license];
  NSLog(@"Update project license");
}

- (NSString *)license
{
  return self.package.license;
}

- (void)setHomepage:(NSString *)homepage
{
  self.package = [CBLPackage package:self.package withHomepage:homepage];
  NSLog(@"Update project homepage");
}

- (NSString *)homepage
{
  return self.package.homepage;
}

- (void)setPkgUrl:(NSString *)pkgUrl
{
  self.package = [CBLPackage package:self.package withPkgUrl:pkgUrl];
  NSLog(@"Update project package URL");
}

- (NSString *)pkgUrl
{
  return self.package.pkgUrl;
}

- (void)setBugReports:(NSString *)bugReports
{
  self.package = [CBLPackage package:self.package withBugReports:bugReports];
  NSLog(@"Update project bug reports");
}

- (NSString *)bugReports
{
  return self.package.bugReports;
}

- (void)setDataDir:(NSString *)dataDir
{
  self.package = [CBLPackage package:self.package withDataDir:dataDir];
  NSLog(@"Update project data directory");
}

- (NSString *)dataDir
{
  return self.package.dataDir;
}

- (void)setDataFiles:(NSDictionary *)dataFiles
{
  self.package = [CBLPackage package:self.package withDataFiles:dictTreeToStrings(dataFiles)];
  NSLog(@"Update project data files");
}

- (NSDictionary *)dataFiles
{
  return stringsToDictTree(self.package.dataFiles);
}

- (void)setExtraSrcFiles:(NSDictionary *)extraSrcFiles
{
  self.package = [CBLPackage package:self.package withExtraSrcFiles:dictTreeToStrings(extraSrcFiles)];
  NSLog(@"Update project extra source files");
}

- (NSDictionary *)extraSrcFiles
{
  return stringsToDictTree(self.package.extraSrcFiles);
}

// executable section

- (void)setExecutableName:(NSString *)executableName
{
  self.package = [CBLPackage package:self.package withExecutableName:executableName];
  NSLog(@"Update project executable name");
}

- (NSString *)executableName
{
  return self.package.executableName;
}

- (void)setSourceDir:(NSString *)sourceDir
{
  self.package = [CBLPackage package:self.package withSourceDir:sourceDir];
  NSLog(@"Update project executable source directory");
}

- (NSString *)sourceDir
{
  return self.package.sourceDir;
}

- (void)setModules:(NSDictionary *)modules
{
  self.package = [CBLPackage package:self.package withModules:dictTreeToStrings(modules)];
  NSLog(@"Update project executable modules");
}

- (NSDictionary *)modules
{
  return stringsToDictTree(self.package.modules);
}


#pragma mark -
#pragma mark Project serialisation

- (NSFileWrapper *)fileWrapperWithError:(NSError *__autoreleasing *)outError
{
#pragma unused(outError)

    // First, we must flush all file wrapper (except the Cabal file one) — i.e., leave out the package group item.
  [self.groupItems flushAllExceptPackageGoup];

    // Then, we flush the Cabal one.
  [self flushCabalFile];

  return self.fileWrapper;
}

- (void)flushCabalFile
{
  ProjectItem *packageGroupItem = self.groupItems.packageGroupItem;

    // Then, we recreate the file-dependent project properties from the model view items — this will change data in the
    // Cabal file if any files were added, deleted, or their names edited
  [self updateDataGroup:self.groupItems.packageGroupItem.children];
  [self updateExecutableGroup:self.groupItems.executableGroupItem.children];
  [self updateExtraSourceGroup:self.groupItems.extraSourceGroupItem.children];

    // Next, we flush any changes to the Cabal file into its string representation and write that through the file
    // wrapper.
  ProjectItem *cabalFileItem  = packageGroupItem.children[0];
  NSString    *newCabalString = [self.package string];
  if (![cabalFileItem.fileContents isEqualToString:newCabalString])        // Better than updating in vain, but a dirty...
    cabalFileItem.fileContents = newCabalString;                          // ...flag on the cabal fields would be even better.
  [self.groupItems flushPackageGroup];
}

- (BOOL)writeCabalFileWithError:(NSError *__autoreleasing *)error
{
  NSFileManager *fileManager      = [NSFileManager defaultManager];
  NSURL         *cabalFileURL     = [self.documentURL URLByAppendingPathComponent:self.cabalFileName];
  NSURL         *cabalFileTempURL = [cabalFileURL URLByAppendingPathExtension:@".temp"];

    // Flush all changes of the view model into the in-memory model.
  [self flushCabalFile];

    // Move the old Cabal file out of the way (otherwise, writing will fail).
  if (![fileManager moveItemAtURL:cabalFileURL toURL:cabalFileTempURL error:error])
    return NO;

    // Write the updated Cabal file.
  NSFileWrapper *cabalFileWrapper = self.fileWrapper.fileWrappers[self.cabalFileName];
  if (! cabalFileWrapper
      || ![cabalFileWrapper writeToURL:cabalFileURL
                               options:0
                   originalContentsURL:nil
                                 error:error]) {

    NSLog(@"%s: writing the updated Cabal file failed", __func__);
    [fileManager moveItemAtURL:cabalFileTempURL toURL:cabalFileURL error:error];  // move the old version back
    return NO;

  }

    // Get rid of the old version of the Cabal file.
  return [fileManager removeItemAtURL:cabalFileTempURL error:error];
}

- (void)updateDataGroup:(NSArray/*<ProjectItem>*/*)items
{
  if (items.count == 1 && ((ProjectItem*)[items firstObject]).isFileGroup) {     // we have got a dataDir

    ProjectItem *dataDirItem = (ProjectItem*)[items firstObject];
    self.dataDir = dataDirItem.identifier;
    items        = dataDirItem.children;

  }

  self.dataFiles = itemsToDictTree(items, NO);
}

- (void)updateExecutableGroup:(NSArray/*<ProjectItem>*/*)items
{
    // For the moment, we have got a single executable.
  if (items.count != 1 || !((ProjectItem*)[items firstObject]).isExecutable)
    return;
  else
    items = ((ProjectItem*)[items firstObject]).children;

  if (items.count == 1 && ((ProjectItem*)[items firstObject]).isFileGroup) {     // we have got a sourceDir

    ProjectItem *sourceDirItem = (ProjectItem*)[items firstObject];
    self.sourceDir = sourceDirItem.identifier;
    items          = sourceDirItem.children;

  }

  self.modules = itemsToDictTree(items, YES);
}

- (void)updateExtraSourceGroup:(NSArray/*<ProjectItem>*/*)items
{
  self.extraSrcFiles = itemsToDictTree(items, NO);
}


#pragma mark -
#pragma mark Data conversions

NSDictionary *stringsToDictTree(NSArray *strings)
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  for (NSString *fname in strings) {

    NSArray             *components = [fname pathComponents];
    NSMutableDictionary *cursor     = dict;
    for (NSString *component in components) {

      if (!cursor[component])             // component not yet in the tree
        cursor[component] = [NSMutableDictionary dictionary];

      cursor = cursor[component];

    }
  }
  return [NSDictionary dictionaryWithDictionary:dict];    // freeze
}

NSArray *dictTreeToStrings(NSDictionary *dicts)
{
  NSMutableArray *strings = [NSMutableArray array];

  for (NSString *component in dicts) {

    NSArray *substrings = dictTreeToStrings(dicts[component]);
    if ([substrings count] == 0)
      [strings addObject:component];
    else
      for (NSString *substring in substrings)
        [strings addObject:[component stringByAppendingPathComponent:substring]];

  }
  return [NSArray arrayWithArray:strings];    // freeze
}

NSDictionary *itemsToDictTree(NSArray *items, BOOL asSourceModules)
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  for (ProjectItem *item in items)
  {
    NSDictionary *children = itemsToDictTree(item.children, asSourceModules);
    NSString     *name     = (asSourceModules && !item.isMainFile)
                             ? [item.identifier stringByDeletingPathExtension]      // remove ".hs" for sources
                             : item.identifier;

      // Empty folders must be pruned as they cannot be represented in the Cabal file. We can't do that after the
      // conversion to dictionary trees as we have lost the information about which empty dictionaries represent files
      // and which ones empty folders.
    if (!item.isEmptyFolder)
      [dict setValue:children forKey:name];
  }
  return [NSDictionary dictionaryWithDictionary:dict];    // freeze
}

@end
