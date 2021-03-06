//
// The MIT License (MIT)
//
// Copyright (c) 2014 MarkdownAnywhere
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

#import "MANoteTableViewController.h"
#import "MANoteTableViewCell.h"
#import "MABookshelf.h"
#import "MANoteViewController.h"

@interface MANoteTableViewController ()
@property (nonatomic,assign) BOOL stopObserving;
@end

@implementation MANoteTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = self.notebook.title;

    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(add:)];
    self.navigationItem.rightBarButtonItems = @[addButton];

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.noteViewController = (MANoteViewController*)[[self.splitViewController.viewControllers lastObject] topViewController];
    }

    [self.tableView registerNib:[MANoteTableViewCell nib] forCellReuseIdentifier:NSStringFromClass([MANoteTableViewCell class])];

    [self.notebook addOSObserver:self selector:@selector(savedNotebook:latest:) notificationType:BZObjectStoreNotificationTypeSaved];

    [self.notebook addOSObserver:self selector:@selector(deletedNotebook:) notificationType:BZObjectStoreNotificationTypeDeleted];
}

- (void)savedNotebook:(MANotebook*)current latest:(MANotebook*)latest
{
    if (self.stopObserving) {
        return;
    }
    self.notebook = latest;
    [self.tableView reloadData];
}

- (void)deletedNotebook:(MANotebook*)current
{
    if (self.stopObserving) {
        return;
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)add:(id)sender
{
    self.stopObserving = YES;
    [self.notebook addNote];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    self.stopObserving = NO;
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.notebook.notes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MANoteTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([MANoteTableViewCell class]) forIndexPath:indexPath];
    MANote *note = self.notebook.notes[indexPath.row];
    [cell showNote:note];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        self.stopObserving = YES;
        MANote *note = self.notebook.notes[indexPath.row];
        [self.notebook removeNote:note];
        [self.garbageBox addNote:note];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        self.stopObserving = NO;
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 70.0f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        MANote *note = self.notebook.notes[indexPath.row];
        self.noteViewController.notebook = self.notebook;
        self.noteViewController.note = note;
        [self.noteViewController show];
    } else {
        [self performSegueWithIdentifier:NSStringFromClass([MANoteViewController class]) sender:self];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:NSStringFromClass([MANoteViewController class])]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        MANoteViewController *vc = [segue destinationViewController];
        vc.notebook = self.notebook;
        vc.note = self.notebook.notes[indexPath.row];;
    }
}

@end

