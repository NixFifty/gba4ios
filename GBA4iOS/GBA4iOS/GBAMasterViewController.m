//
//  GBAMasterViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 5/23/12.
//  Copyright (c) 2012 Testut Tech. All rights reserved.
//

#import "GBAMasterViewController.h"

#import "GBADetailViewController.h"
#import "WebBrowserViewController.h"

@interface GBAMasterViewController ()
@property (strong, nonatomic) NSMutableDictionary *romDictionary;
@property (strong, nonatomic) NSArray *romSections;
@property (nonatomic) NSInteger currentSection_;
@end

@implementation GBAMasterViewController

@synthesize detailViewController = _detailViewController;
@synthesize romDictionary;
@synthesize romSections;
@synthesize currentSection_;
@synthesize currentRomPath;

- (void)awakeFromNib
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
    }
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(scanRomDirectory)];
    self.navigationItem.leftBarButtonItem = refreshButton;
    
    [self scanRomDirectory];

    UIBarButtonItem *searchButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(getMoreROMs)];
    self.navigationItem.rightBarButtonItem = searchButton;
    self.detailViewController = (GBADetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self scanRomDirectory];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

#pragma mark -
#pragma mark ROM loading methods

- (void)scanRomDirectory {
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    
    [self.romDictionary removeAllObjects];
    if (!self.romDictionary) {
        self.romDictionary = [[NSMutableDictionary alloc] init];
    }
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:documentsDirectoryPath error:nil];
    
    self.romSections = [NSArray arrayWithArray:[@"A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|#" componentsSeparatedByString:@"|"]];
    
    for (int i = 0; i < contents.count; i++) {
        NSString *filename = [contents objectAtIndex:i];
        if ([filename hasSuffix:@".zip"] || [filename hasSuffix:@".ZIP"] || [filename hasSuffix:@".gba"] || [filename hasSuffix:@".GBA"] || [filename hasSuffix:@".ips"] || [filename hasSuffix:@".IPS"]) { 
            NSString* characterIndex = [filename substringWithRange:NSMakeRange(0,1)];
            
            BOOL matched = NO;
            for (int i = 0; i < self.romSections.count && !matched; i++) {
                NSString *section = [self.romSections objectAtIndex:i];
                if ([section isEqualToString:characterIndex]) {
                    matched = YES;
                }
            }
            
            if (!matched) {
                characterIndex = @"#";
            }
            
            NSMutableArray *sectionArray = [self.romDictionary objectForKey:characterIndex];
            if (sectionArray == nil) {
                sectionArray = [[NSMutableArray alloc] init];
            }
            [sectionArray addObject:filename];
            [self.romDictionary setObject:sectionArray forKey:characterIndex];
        }
    }
    
    [self.tableView reloadData];
    
    [self importSaveStates];
}

- (void) importSaveStates {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *saveStateDirectory = [documentsDirectory stringByAppendingPathComponent:@"Save States"];
    
    NSArray* dirContents = [fileManager contentsOfDirectoryAtPath:documentsDirectory error:nil];
    [dirContents enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *filename = obj;
        if ([filename hasSuffix:@"svs"]) {
            NSError *error = nil;
            NSString *romName = [filename stringByDeletingPathExtension];
            
            NSRange range = NSMakeRange([romName length] - 1, 1);
            NSString *saveSlot = [romName substringWithRange:range];
            NSInteger saveSlotNumber = [saveSlot integerValue];
            NSString *destinationFilename = [NSString stringWithFormat:@"%@.svs", saveSlot];
            
            romName = [romName substringToIndex:[romName length] - 1];
            
            NSString *originalFilePath = [documentsDirectory stringByAppendingPathComponent:filename];
            NSString *romSaveStateDirectory = [saveStateDirectory stringByAppendingPathComponent:romName]; 
            NSString *saveStateInfoPath = [romSaveStateDirectory stringByAppendingPathComponent:@"info.plist"];
            
            [fileManager createDirectoryAtPath:romSaveStateDirectory withIntermediateDirectories:YES attributes:nil error:nil];
            
            NSMutableArray *array = [[NSMutableArray alloc] initWithContentsOfFile:saveStateInfoPath];
            
            if ([array count] == 0) {
                array = [[NSMutableArray alloc] initWithCapacity:5];
                
                for (int i = 0; i < 5; i++) {
                    [array addObject:NSLocalizedString(@"Empty", @"")];
                }
            }
            [array replaceObjectAtIndex:saveSlotNumber withObject:NSLocalizedString(@"Imported", @"")];
            [array writeToFile:saveStateInfoPath atomically:YES];
            
            NSString *destinationFilePath = [romSaveStateDirectory stringByAppendingPathComponent:destinationFilename];
            
            if ([fileManager copyItemAtPath:originalFilePath toPath:destinationFilePath error:&error] && !error) {
                [fileManager removeItemAtPath:originalFilePath error:nil];
                NSLog(@"Successfully copied svs file to svs directory");
            }
            else {
                NSLog(@"%@. %@.", error, [error userInfo]);
            }
        }
    }];
}

#pragma mark Download ROMs

- (void)getMoreROMs {
    WebBrowserViewController *webViewController = [[WebBrowserViewController alloc] init];
    UINavigationController *webNavController = [[UINavigationController alloc] initWithRootViewController:webViewController];
	webNavController.navigationBar.barStyle = UIBarStyleBlack;
    [self presentModalViewController:webNavController animated:YES];
}

#pragma mark - Table view data source

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = nil;
            
    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];        
    }
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    NSString *filename = [[self.romDictionary objectForKey:[self.romSections objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
    filename = [filename stringByDeletingPathExtension];//cleaner interface
    cell.textLabel.text = filename;
    
    return cell;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger numberOfSections = self.romSections.count;    
    return numberOfSections > 0 ? numberOfSections : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *sectionTitle = nil;    
    if(self.romSections.count) {
        NSInteger numberOfRows = [self tableView:tableView numberOfRowsInSection:section];
        if (numberOfRows > 0) {
            sectionTitle = [self.romSections objectAtIndex:section];
        }
    }    
    return sectionTitle;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    NSMutableArray *sectionIndexTitles = nil;
    if(self.romSections.count) {
        sectionIndexTitles = [NSMutableArray arrayWithArray:[@"A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|#" componentsSeparatedByString:@"|"]];
    }
    return  sectionIndexTitles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    self.currentSection_ = index;
    return index;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numberOfRows = self.romDictionary.count;
    if(self.romSections.count) {
        numberOfRows = [[self.romDictionary objectForKey:[self.romSections objectAtIndex:section]] count];
    }
    return numberOfRows;
}

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

- (NSString *)romPathAtIndexPath:(NSIndexPath *)indexPath {
    return [[self.romDictionary objectForKey:[self.romSections objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectoryPath = [paths objectAtIndex:0];
        
        self.currentRomPath = [documentsDirectoryPath stringByAppendingPathComponent:[self romPathAtIndexPath:indexPath]];
        self.detailViewController.detailItem = self.currentRomPath;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        NSString *rom = [self romPathAtIndexPath:indexPath];
        [[segue destinationViewController] setDetailItem:rom];
    }
    else if ([[segue identifier] isEqualToString:@"loadROM"]) {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectoryPath = [paths objectAtIndex:0];
            
            UITableViewCell *cell = (UITableViewCell *)sender;
            self.currentRomPath = [documentsDirectoryPath stringByAppendingPathComponent:[self romPathAtIndexPath:[self.tableView indexPathForCell:cell]]];
            
            [UIApplication sharedApplication].statusBarHidden = YES;
            GBAEmulatorViewController *emulatorViewController = [segue destinationViewController];
            emulatorViewController.wantsFullScreenLayout = YES;
            emulatorViewController.romPath = self.currentRomPath;
        }
        
    }
}

@end