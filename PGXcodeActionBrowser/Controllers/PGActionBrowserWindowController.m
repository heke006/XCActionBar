//
//  PGActionBrowserWindowController.m
//  PGXcodeActionBrowser
//
//  Created by Pedro Gomes on 11/03/2015.
//  Copyright (c) 2015 Pedro Gomes. All rights reserved.
//

#import "PGActionBrowserWindowController.h"
#import "PGActionInterface.h"
#import "PGSearchService.h"

#import "PGSearchResultCell.h"
//NSUpArrowFunctionKey        = 0xF700,
//NSDownArrowFunctionKey      = 0xF701,
//NSLeftArrowFunctionKey      = 0xF702,
//NSRightArrowFunctionKey     = 0xF703,

typedef BOOL (^PGCommandHandler)(void);

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@interface PGActionBrowserWindowController () <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSWindowDelegate>

@property (nonatomic) NSRect frameForEmptySearchResults;
@property (nonatomic) CGFloat searchFieldBottomConstraintConstant;

@property (nonatomic) NSDictionary *commandHandlers;

@property (weak) IBOutlet NSTextField *searchField;
@property (weak) IBOutlet NSTableView *searchResultsTable;
@property (weak) IBOutlet NSLayoutConstraint *searchFieldBottomConstraint;
@property (weak) IBOutlet NSLayoutConstraint *searchResultsTableHeightConstraint;
@property (weak) IBOutlet NSLayoutConstraint *searchResultsTableBottomConstraint;

@property (nonatomic) NSArray *searchResults;

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@implementation PGActionBrowserWindowController

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (id)initWithBundle:(NSBundle *)bundle
{
    if((self = [super initWithWindowNibName:NSStringFromClass([PGActionBrowserWindowController class])])) {
        
    }
    return self;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)windowDidLoad
{
    [super windowDidLoad];
    
    RTVDeclareWeakSelf(weakSelf);
    self.commandHandlers = @{NSStringFromSelector(@selector(moveDown:)):     [^BOOL { return [weakSelf selectNextSearchResult]; } copy],
                             NSStringFromSelector(@selector(moveUp:)):       [^BOOL { return [weakSelf selectPreviousSearchResult]; } copy],
                             NSStringFromSelector(@selector(insertNewline:)):[^BOOL { return [weakSelf executeSelectedAction]; } copy]
                             };
    
    self.searchField.focusRingType = NSFocusRingTypeNone;
    self.searchField.delegate      = self;
    self.searchField.nextResponder = self;
    
    self.searchResultsTable.rowSizeStyle            = NSTableViewRowSizeStyleMedium;
    self.searchResultsTable.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
    
    [self restoreWindowSize];
    [self.window setDelegate:self];
    [self.window makeFirstResponder:self.searchField];
}

#pragma mark - Event Handling

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)cancelOperation:(id)sender
{
    [self close];
}

//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
- (void)keyDown:(NSEvent *)theEvent
{
    TRLog(@"<KeyDown>, <event=%@>", theEvent);
    
    [super keyDown:theEvent];
}

#pragma mark - NSWindowDelegate

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)windowDidBecomeKey:(NSNotification *)notification
{
    self.searchFieldBottomConstraintConstant = self.searchFieldBottomConstraint.constant;
    self.frameForEmptySearchResults = self.window.frame;
    
    [self.window makeFirstResponder:self.searchField];
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)windowDidResignKey:(NSNotification *)notification
{
    [self close];
    [self restoreWindowSize];
}

#pragma mark - NSTextDelegate

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)controlTextDidChange:(NSNotification *)notification
{
    NSTextField *textField = notification.object;

//    TRLog(@"<SearchQueryChanged>, <query=%@>", textField.stringValue);

    // TODO: wait a bit before attempting to update search results - cancel previous update if any
    RTVDeclareWeakSelf(weakSelf);
    
    [self.searchService performSearchWithQuery:textField.stringValue
                             completionHandler:^(NSArray *results) {
                                 [weakSelf updateSearchResults:results];
                                 [weakSelf resizeWindowToAccomodateSearchResults];
    }];
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
    TRLog(@"<doCommandBySelector>, <cmd=%@>", NSStringFromSelector(command));
    
    NSString *commandKey = NSStringFromSelector(command);
    BOOL handleCommand   = (TRCheckContainsKey(self.commandHandlers, commandKey) == YES);
    if(handleCommand == YES) {
        PGCommandHandler commandHandler = self.commandHandlers[commandKey];
        return commandHandler();
    }
    return handleCommand;
}

#pragma mark - NSTableViewDataSource

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return self.searchResults.count;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    return self.searchResults[rowIndex];
}

#pragma mark - NSTableViewDelegate

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    PGSearchResultCell *cell = [tableView makeViewWithIdentifier:NSStringFromClass([PGSearchResultCell class]) owner:self];
    
    id<PGActionInterface> action = self.searchResults[row];
    [cell.textField setStringValue:[NSString stringWithFormat:@"%@ (%@) [%@]", action.title, action.hint, action.subtitle]];
    
    return cell;
}

#pragma mark - Public Methods

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)updateSearchResults:(NSArray *)results
{
    TRLog(@"<UpdatedSearchResults>, <results=%@>", results);
    
    self.searchResults = results;
    [self.searchResultsTable reloadData];
    
    if(TRCheckIsEmpty(self.searchResultsTable) == NO) {
        [self selectSearchResultAtIndex:0];
    }
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)clearSearchResults
{
    [self updateSearchResults:@[]];
}

#pragma mark - Event Action Handlers

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (BOOL)selectNextSearchResult
{
    TRLog(@"<selectNextSearchResult>");
    
    NSInteger rowCount      = [self.searchResultsTable numberOfRows];
    NSInteger selectedIndex = self.searchResultsTable.selectedRow;
    NSInteger indexToSelect = (selectedIndex == -1 ? 0 : (selectedIndex + 1 < rowCount ? selectedIndex + 1 : 0));
    
    [self selectSearchResultAtIndex:indexToSelect];

    return YES;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (BOOL)selectPreviousSearchResult
{
    TRLog(@"<selectPreviousSearchResult>");
    
    NSInteger rowCount      = [self.searchResultsTable numberOfRows];
    NSInteger selectedIndex = self.searchResultsTable.selectedRow;
    NSInteger indexToSelect = (selectedIndex == -1 ? rowCount - 1 : (selectedIndex - 1 >= 0 ? selectedIndex - 1 : rowCount - 1));
    
    [self selectSearchResultAtIndex:indexToSelect];

    return YES;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (BOOL)executeSelectedAction
{
    NSInteger selectedIndex = self.searchResultsTable.selectedRow;
    if(selectedIndex == -1) return NO;
    
    id<PGActionInterface> selectedAction = self.searchResults[selectedIndex];
    BOOL executed = [selectedAction execute];

    [self close];
    
    return executed;
}

#pragma mark - Helpers

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)selectSearchResultAtIndex:(NSInteger)indexToSelect
{
    [self.searchResultsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:indexToSelect]
                         byExtendingSelection:NO];
    [self.searchResultsTable scrollRowToVisible:indexToSelect];
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)resizeWindowToAccomodateSearchResults
{
    if(TRCheckIsEmpty(self.searchResults) == NO) {
        self.searchResultsTable.alphaValue = 1.0;
        self.searchResultsTable.hidden = NO;
        self.searchResultsTableBottomConstraint.constant = 10.0;
        self.searchResultsTableHeightConstraint.constant = 250.0;
    }
    else [self restoreWindowSize];
    
    [self.searchField layoutSubtreeIfNeeded];
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)restoreWindowSize
{
    self.searchResultsTable.alphaValue = 0.0;
    self.searchResultsTable.hidden = YES;
    self.searchResultsTableBottomConstraint.constant = 0.0;
    self.searchResultsTableHeightConstraint.constant = 0.0;
    
    [self.window.contentView layoutSubtreeIfNeeded];
}

@end
