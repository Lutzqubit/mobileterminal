// -*- mode:objc -*-
// $Id: PTYTextView.m,v 1.307 2007/06/17 01:56:31 ujwal Exp $
/*
 **  PTYTextView.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Setlur
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: NSTextView subclass. The view object for the VT100 screen.
 **
 **  This program is free software; you can redistribute it and/or modify
 **  it under the terms of the GNU General Public License as published by
 **  the Free Software Foundation; either version 2 of the License, or
 **  (at your option) any later version.
 **
 **  This program is distributed in the hope that it will be useful,
 **  but WITHOUT ANY WARRANTY; without even the implied warranty of
 **  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 **  GNU General Public License for more details.
 **
 **  You should have received a copy of the GNU General Public License
 **  along with this program; if not, write to the Free Software
 **  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#define DEBUG_ALLOC           1 
#define DEBUG_METHOD_TRACE    1
#define GREED_KEYDOWN         1

#import "PTYTextView.h"
#import "VT100Screen.h"
#import <UIKit/NSString-UIStringDrawing.h>

#include <sys/time.h>

//static NSCursor* textViewCursor =  nil;
//static float strokeWidth, boldStrokeWidth;
static int cacheSize;

@implementation PTYTextView

+ (void) initialize
{
}

- (id)initWithFrame: (struct CGRect) aRect
{
#if DEBUG_ALLOC
  NSLog(@"%s: 0x%x", __PRETTY_FUNCTION__, self);
#endif
  self = [super initWithFrame: aRect];
  
  dataSource=_delegate=markedTextAttributes=NULL;
   /* 
    [self setMarkedTextAttributes:
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSColor yellowColor], NSBackgroundColorAttributeName,
            [NSColor blackColor], NSForegroundColorAttributeName,
            //nafont, NSFontAttributeName,
            [NSNumber numberWithInt:2],NSUnderlineStyleAttributeName,
            NULL]];
*/
  CURSOR=YES;
  lastFindX = startX = -1;
  gettimeofday(&lastBlink, NULL);
	    	
  memset(charImages, 0, cacheSize*sizeof(CharCache));	
  charWidth = 12;
  oldCursorX = oldCursorY = -1;
  return (self);
}

- (BOOL) canBecomeFirstResponder;
{
  return NO;
}

- (void) dealloc
{
#if DEBUG_ALLOC
    NSLog(@"%s: 0x%x", __PRETTY_FUNCTION__, self);
#endif
   /* 
	int i;
	if(mouseDownEvent != nil)
    {
		[mouseDownEvent release];
		mouseDownEvent = nil;
    }
	 
    //NSLog(@"remove tracking");
    if(trackingRectTag)
		[self removeTrackingRect:trackingRectTag];
	
    [[NSNotificationCenter defaultCenter] removeObserver:self];    
    for(i=0;i<16;i++) {
        [colorTable[i] release];
    }
    [defaultFGColor release];
    [defaultBGColor release];
    [defaultBoldColor release];
    [selectionColor release];
	[defaultCursorColor release];
*/
	
//    [font release];
//	[nafont release];
    [markedTextAttributes release];
//	[markedText release];
	
    [super dealloc];
    
#if DEBUG_ALLOC
    NSLog(@"%s: 0x%x, done", __PRETTY_FUNCTION__, self);
#endif
}
/*
- (BOOL)shouldDrawInsertionPoint
{
#if 0 // DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView shouldDrawInsertionPoint]",
          __FILE__, __LINE__);
#endif
    return NO;
}
*/

- (BOOL)isFlipped
{
    return YES;
}
/*
- (BOOL)isOpaque
{
    return YES;
}
*/

- (BOOL) blinkingCursor
{
  return (blinkingCursor);
}

- (void) setBlinkingCursor: (BOOL) bFlag
{
  blinkingCursor = bFlag;
}


- (NSDictionary*) markedTextAttributes
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView selectedTextAttributes]",
          __FILE__, __LINE__);
#endif
    return markedTextAttributes;
}

- (void) setMarkedTextAttributes: (NSDictionary *) attr
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView setSelectedTextAttributes:%@]",
          __FILE__, __LINE__,attr);
#endif
    [markedTextAttributes release];
    [attr retain];
    markedTextAttributes=attr;
}

/*
- (void) setFGColor:(NSColor*)color
{
    [defaultFGColor release];
    [color retain];
    defaultFGColor=color;
	[self resetCharCache];
	forceUpdate = YES;
	[self setNeedsDisplay];
	// reset our default character attributes    
}

- (void) setBGColor:(NSColor*)color
{
    [defaultBGColor release];
    [color retain];
    defaultBGColor=color;
	//    bg = [bg colorWithAlphaComponent: [[SESSION backgroundColor] alphaComponent]];
	//    fg = [fg colorWithAlphaComponent: [[SESSION foregroundColor] alphaComponent]];
	forceUpdate = YES;
	[self resetCharCache];
	[self setNeedsDisplay];
}

- (void) setBoldColor: (NSColor*)color
{
    [defaultBoldColor release];
    [color retain];
    defaultBoldColor=color;
	[self resetCharCache];
	forceUpdate = YES;
	[self setNeedsDisplay];
}

- (void) setCursorColor: (NSColor*)color
{
    [defaultCursorColor release];
    [color retain];
    defaultCursorColor=color;
	forceUpdate = YES;
	[self setNeedsDisplay];
}

- (void) setCursorTextColor:(NSColor*) aColor
{
	[cursorTextColor release];
	[aColor retain];
	cursorTextColor = aColor;
	[self _clearCacheForColor: CURSOR_TEXT];
	
	forceUpdate = YES;
	[self setNeedsDisplay];

}

- (NSColor *) cursorTextColor
{
	return (cursorTextColor);
}

- (NSColor *) defaultFGColor
{
    return defaultFGColor;
}

- (NSColor *) defaultBGColor
{
	return defaultBGColor;
}

- (NSColor *) defaultBoldColor
{
    return defaultBoldColor;
}

- (NSColor *) defaultCursorColor
{
    return defaultCursorColor;
}


- (void) setColorTable:(int) index highLight:(BOOL)hili color:(NSColor *) c
{
	int idx=(hili?1:0)*8+index;
	
    [colorTable[idx] release];
    [c retain];
    colorTable[idx]=c;
	[self _clearCacheForColor: idx];
	[self _clearCacheForColor: (BOLD_MASK | idx)];
	[self _clearCacheForBGColor: idx];
	
	[self setNeedsDisplay];
}

- (NSColor *) colorForCode:(unsigned int) index 
{
    NSColor *color;
	
	if (index&DEFAULT_FG_COLOR_CODE) // special colors?
    {
		switch (index) {
			case SELECTED_TEXT:
				color = selectedTextColor;
				break;
			case CURSOR_TEXT:
				color = cursorTextColor;
				break;
			case DEFAULT_BG_COLOR_CODE:
				color = defaultBGColor;
				break;
			default:
				if(index&BOLD_MASK)
				{
					color = index-BOLD_MASK == DEFAULT_BG_COLOR_CODE ? defaultBGColor : [self defaultBoldColor];
				}
				else
				{
					color = defaultFGColor;
				}
		}
    }
    else 
    {
		index &= 0xff;
		
        if (index<16) {
			color=colorTable[index];
		}
		else if (index<232) {
			index -= 16;
			color=[NSColor colorWithCalibratedRed:(index/36) ? ((index/36)*40+55)/256.0:0 
											green:(index%36)/6 ? (((index%36)/6)*40+55)/256.0:0 
											 blue:(index%6) ?((index%6)*40+55)/256.0:0
											alpha:1];
		}
		else {
			index -= 232;
			color=[NSColor colorWithCalibratedWhite:(index*10+8)/256.0 alpha:1];
		}
    }
	
    return color;
    
}

- (NSColor *) selectionColor
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView selectionColor]",
          __FILE__, __LINE__);
#endif
    
    return selectionColor;
}

- (void) setSelectionColor: (NSColor *) aColor
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView setSelectionColor:%@]",
          __FILE__, __LINE__,aColor);
#endif
    
    [selectionColor release];
    [aColor retain];
    selectionColor=aColor;
	forceUpdate = YES;
	[self setNeedsDisplay];
}


- (NSFont *)font
{
    return font;
}

- (NSFont *)nafont
{
    return nafont;
}

- (void) setFont:(NSFont*)aFont nafont:(NSFont *)naFont;
{    
	NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    NSSize sz;
	
    [dic setObject:aFont forKey:NSFontAttributeName];
    sz = [@"W" sizeWithAttributes:dic];
	
	charWidthWithoutSpacing = sz.width;
	charHeightWithoutSpacing = [aFont defaultLineHeightForFont];
	
    [font release];
    [aFont retain];
    font=aFont;
    [nafont release];
    [naFont retain];
    nafont=naFont;
    [self setMarkedTextAttributes:
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSColor yellowColor], NSBackgroundColorAttributeName,
            [NSColor blackColor], NSForegroundColorAttributeName,
            nafont, NSFontAttributeName,
            [NSNumber numberWithInt:2],NSUnderlineStyleAttributeName,
            NULL]];
	[self resetCharCache];
	forceUpdate = YES;
	[self setNeedsDisplay];
}

- (void)changeFont:(id)fontManager
{
	if ([ITConfigPanelController onScreen])
		[[ITConfigPanelController singleInstance] changeFont:fontManager];
	else
		[super changeFont:fontManager];
}
*/

- (void) resetCharCache
{
/*
	int loop;
	for (loop=0;loop<cacheSize;loop++)
    {
		[charImages[loop].image release];
		charImages[loop].image=nil;
    }
*/
}

- (VT100Screen*) dataSource
{
    return (dataSource);
}

- (void) setDataSource: (VT100Screen*) aDataSource
{
    id temp = dataSource;
    
    [temp acquireLock];
    dataSource = aDataSource;
    [temp releaseLock];
}
/*
- (id) delegate
{
    return _delegate;
}

- (void) setDelegate: (id) aDelegate
{
    _delegate = aDelegate;
}    
*/

- (float) lineHeight
{
    return (lineHeight);
}

- (void) setLineHeight: (float) aLineHeight
{
    lineHeight = aLineHeight;
}

- (float) lineWidth
{
    return (lineWidth);
}

- (void) setLineWidth: (float) aLineWidth
{
    lineWidth = aLineWidth;
}

- (float) charWidth
{
	return (charWidth);
}

- (void) setCharWidth: (float) width
{
	charWidth = width;
}

- (void) setForceUpdate: (BOOL) flag
{
	forceUpdate = flag;
}


// We override this method since both refresh and window resize can conflict resulting in this happening twice
// So we do not allow the size to be set larger than what the data source can fill
- (void) setFrameSize: (NSSize) aSize
{
return;
	//NSLog(@"%s (0x%x): setFrameSize to (%f,%f)", __PRETTY_FUNCTION__, self, aSize.width, aSize.height);
/*
	NSSize anotherSize = aSize;
	
	anotherSize.height = [dataSource numberOfLines] * lineHeight;

	[super setFrameSize: anotherSize];
	
    if (![(PTYScroller *)([[self enclosingScrollView] verticalScroller]) userScroll]) 
    {
        [self scrollEnd];
    }
    
	// reset tracking rect
	if(trackingRectTag)
		[self removeTrackingRect:trackingRectTag];
	trackingRectTag = [self addTrackingRect:[self visibleRect] owner: self userData: nil assumeInside: NO];
*/
}

- (void) refresh
{
	//NSLog(@"%s: 0x%x", __PRETTY_FUNCTION__, self);
	struct CGRect aFrame;
	int height;
    
    if(dataSource != nil)
    {
		[dataSource acquireLock];
        numberOfLines = [dataSource numberOfLines];
		[dataSource releaseLock];

        height = numberOfLines * lineHeight;
		aFrame = [self frame];
		
        if(height != aFrame.size.height)
        {
            
			//NSLog(@"%s: 0x%x; new number of lines = %d; resizing height from %f to %d", 
			//	  __PRETTY_FUNCTION__, self, numberOfLines, [self frame].size.height, height);
            aFrame.size.height = height;
            [self setFrame: aFrame];
// TODO(allen): Scroll
/*
			if (![(PTYScroller *)([[self enclosingScrollView] verticalScroller]) userScroll]) 
			{
				[self scrollEnd];
			}
*/
        }
				
		
		[self setNeedsDisplay];
    }
	
}

- (CGRect)adjustScroll:(CGRect)proposedVisibleRect
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView adjustScroll]", __FILE__, __LINE__ );
#endif
	proposedVisibleRect.origin.y=(int)(proposedVisibleRect.origin.y/lineHeight+0.5)*lineHeight;

//	if([(PTYScrollView *)[self enclosingScrollView] backgroundImage] != nil)
//        forceUpdate = YES; // we have to update everything if there's a background image
    
	[self setNeedsDisplay];
	return proposedVisibleRect;
}

-(void) scrollLineUp: (id) sender
{
    CGRect scrollRect;
    
    scrollRect= [self visibleRect];
//    scrollRect.origin.y-=[[self enclosingScrollView] verticalLineScroll];
    scrollRect.origin.y-=[self lineHeight];
    //NSLog(@"%f/%f",[[self enclosingScrollView] verticalLineScroll],[[self enclosingScrollView] verticalPageScroll]);
    [self scrollRectToVisible: scrollRect];
}

-(void) scrollLineDown: (id) sender
{
    CGRect scrollRect;
    
    scrollRect= [self visibleRect];
//    scrollRect.origin.y+=[[self enclosingScrollView] verticalLineScroll];
    scrollRect.origin.y+=[self lineHeight];
    [self scrollRectToVisible: scrollRect];
}

-(void) scrollPageUp: (id) sender
{
    CGRect scrollRect;
	
    scrollRect= [self visibleRect];
//    scrollRect.origin.y-= scrollRect.size.height - [[self enclosingScrollView] verticalPageScroll];
    scrollRect.origin.y-= scrollRect.size.height - [self lineHeight];
    [self scrollRectToVisible: scrollRect];
}

-(void) scrollPageDown: (id) sender
{
    CGRect scrollRect;
    
    scrollRect= [self visibleRect];
    scrollRect.origin.y+= scrollRect.size.height - [self lineHeight];
//    scrollRect.origin.y+= scrollRect.size.height - [[self enclosingScrollView] verticalPageScroll];
    [self scrollRectToVisible: scrollRect];
}

-(void) scrollHome
{
    CGRect scrollRect;
    
    scrollRect= [self visibleRect];
    scrollRect.origin.y = 0;
    [self scrollRectToVisible: scrollRect];
}

- (void)scrollEnd
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView scrollEnd]", __FILE__, __LINE__ );
#endif
    
    if (numberOfLines > 0)
    {
        CGRect aFrame;
		aFrame.origin.x = 0;
		aFrame.origin.y = (numberOfLines - 1) * lineHeight;
		aFrame.size.width = [self frame].size.width;
		aFrame.size.height = lineHeight;
		[self scrollRectToVisible: aFrame];
    }
}

- (void)scrollToSelection
{
	CGRect aFrame;
	aFrame.origin.x = 0;
	aFrame.origin.y = startY * lineHeight;
	aFrame.size.width = [self frame].size.width;
	aFrame.size.height = (endY - startY + 1) *lineHeight;
	[self scrollRectToVisible: aFrame];
}

-(void) hideCursor
{
    CURSOR=NO;
}

-(void) showCursor
{
    CURSOR=YES;
}

- (void)drawRect:(CGRect)rect
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(0x%x):-[PTYTextView drawRect:(%f,%f,%f,%f) frameRect: (%f,%f,%f,%f)]",
          __PRETTY_FUNCTION__, self,
          rect.origin.x, rect.origin.y, rect.size.width, rect.size.height,
		  [self frame].origin.x, [self frame].origin.y, [self frame].size.width, [self frame].size.height);
#endif
		
    int numLines, i, j, lineOffset, WIDTH;
	int startScreenLineIndex,line;
    screen_char_t *theLine;
//	struct CGRect bgRect;
//	NSColor *aColor;
//	char  *dirty = NULL;
//	BOOL need_draw;
	float curX, curY;
//	unsigned int bgcode = 0, fgcode = 0;
//	int y1, x1;
//	BOOL double_width;
//	BOOL reversed = [[dataSource terminal] screenMode]; 
    struct timeval now;
	int bgstart;
//	BOOL hasBGImage = NO;  //[(PTYScrollView *)[self enclosingScrollView] backgroundImage] != nil;
//	BOOL fillBG = NO;
    
    //float trans = useTransparency ? 1.0 - transparency : 1.0;
NSLog(@"line height=%d", lineHeight); 
NSLog(@"line width=%d", lineWidth); 

    if(lineHeight <= 0 || lineWidth <= 0) {
      NSLog(@"No line height or width set!");
      return;
    }

    // get lock on source 
    if (![dataSource tryLock]) return;
	
    gettimeofday(&now, NULL);
    if (now.tv_sec*10+now.tv_usec/100000 >= lastBlink.tv_sec*10+lastBlink.tv_usec/100000+7) {
        blinkShow = !blinkShow;
        lastBlink = now;
    }

    NSString* out_hack = @"";

    
	if (forceUpdate) {
/*
		if ([[[dataSource session] parent] fullScreen]) {
			[[[self window] contentView] lockFocus];
			[[NSColor blackColor] set];
			NSRectFill([[self window] frame]);
			[[[self window] contentView] unlockFocus];
		}
		
		if(hasBGImage)
		{
			[(PTYScrollView *)[self enclosingScrollView] drawBackgroundImageRect: rect];
		}
		else {
			aColor = [self colorForCode:(reversed ? [[dataSource terminal] foregroundColorCode] : [[dataSource terminal] backgroundColorCode])];
			aColor = [aColor colorWithAlphaComponent: trans];
			[aColor set];
			NSRectFill(rect);
		}
*/
	}
		
	WIDTH=[dataSource width];

	// Starting from which line?
	lineOffset = rect.origin.y/lineHeight;
    
	// How many lines do we need to draw?
	numLines = ceil(rect.size.height/lineHeight);

	// Which line is our screen start?
	startScreenLineIndex=[dataSource numberOfLines] - [dataSource height];
    //NSLog(@"%f+%f->%d+%d", rect.origin.y,rect.size.height,lineOffset,numLines);
		
    // [self adjustScroll] should've made sure we are at an integer multiple of a line
	curY=(lineOffset+1)*lineHeight;
	
	// redraw margins if we have a background image, otherwise we can still "see" the margin
/*
	if([(PTYScrollView *)[self enclosingScrollView] backgroundImage] != nil)
	{
		bgRect = NSMakeRect(0, rect.origin.y, MARGIN, rect.size.height);
		[(PTYScrollView *)[self enclosingScrollView] drawBackgroundImageRect: bgRect];
		bgRect = NSMakeRect(rect.size.width - MARGIN, rect.origin.y, MARGIN, rect.size.height);
		[(PTYScrollView *)[self enclosingScrollView] drawBackgroundImageRect: bgRect];
	}
*/
	
      
    for(i = 0; i < numLines; i++)
    {
		curX = MARGIN;
        line = i + lineOffset;
		
		if(line >= [dataSource numberOfLines])
		{
			NSLog(@"%s (0x%x): illegal line index %d >= %d", __PRETTY_FUNCTION__, self, line, [dataSource numberOfLines]);
			break;
		}
		
		// get the line
		theLine = [dataSource getLineAtIndex:line];
		//NSLog(@"the line = '%@'", [dataSource getLineString:theLine]);
	/*	
		// Check if we are drawing a line in scrollback buffer
		if (line < startScreenLineIndex) 
		{
			//NSLog(@"Buffer: %d",line);
			dirty = nil;
		}
		else 
		{ 
			// get the dirty flags
			dirty=[dataSource dirty]+(line-startScreenLineIndex)*WIDTH;
			//NSLog(@"Screen: %d",(line-startScreenLineIndex));
		}	
*/
		
		//draw background here
		bgstart = -1;
		
		for(j = 0; j < WIDTH; j++) 
		{
			if (theLine[j].ch == 0xffff) 
				continue;
/*			
			// Check if we need to redraw the background
			// do something to define need_draw
			need_draw = ((line < startScreenLineIndex || dirty[j] || forceUpdate) 
                         && (theLine[j].ch == 0 || // it's a space, so we have to redraw the bg
                             (theLine[j].bg_color & SELECTION_MASK) || // selected, redraw the bg
                             hasBGImage)) // there's a background image
                || (!blinkShow &&(theLine[j].fg_color & BLINK_MASK)); // force to draw if it's the off-phase of blinking
			
			// if we don't have to update next char, finish pending jobs
			if (!need_draw)
			{
				if (bgstart >= 0) 
				{

					bgRect = NSMakeRect(floor(curX+bgstart*charWidth),curY-lineHeight,ceil((j-bgstart)*charWidth),lineHeight);
*/
/*
					// if we have a background image and we are using the background image, redraw image
					if (fillBG) {
						aColor = (bgcode & SELECTION_MASK) ? selectionColor : [self colorForCode: (reversed && bgcode == DEFAULT_BG_COLOR_CODE) ? DEFAULT_FG_COLOR_CODE: bgcode]; 
						aColor = [aColor colorWithAlphaComponent: trans];
						[aColor set];
						NSRectFillUsingOperation(bgRect, hasBGImage?NSCompositeSourceOver:NSCompositeCopy);
					}

				}						
				bgstart = -1;
			}
			else 
			{
				if (bgstart < 0) { // any left over job?
					bgstart = j; 
					bgcode = theLine[j].bg_color & 0x3ff;
					fillBG = (bgcode & SELECTION_MASK) || 
                        (theLine[j].ch == 0 && (reversed || bgcode!=DEFAULT_BG_COLOR_CODE || !hasBGImage)) || 
                        (theLine[j].fg_color & BLINK_MASK && !blinkShow && // off-phase of a blink character?
                            (!hasBGImage || bgcode!=DEFAULT_BG_COLOR_CODE)); // No draw if it has a bg image or the background color is the default
				}
				else if (theLine[j].bg_color != bgcode || ((bgcode & SELECTION_MASK) || (theLine[j].ch == 0 && (reversed || bgcode!=DEFAULT_BG_COLOR_CODE || !hasBGImage)) || (theLine[j].fg_color & BLINK_MASK && !blinkShow && (!hasBGImage ||bgcode!=DEFAULT_BG_COLOR_CODE))) != fillBG) 
				{ 
					//background change
					bgRect = NSMakeRect(floor(curX+bgstart*charWidth),curY-lineHeight,ceil((j-bgstart)*charWidth),lineHeight);
					// if we have a background image and we are using the background image, redraw image
					if( hasBGImage)
					{
						[(PTYScrollView *)[self enclosingScrollView] drawBackgroundImageRect: bgRect];
					}
					if (fillBG) {
						aColor = (bgcode & SELECTION_MASK) ? selectionColor : [self colorForCode: (reversed && bgcode == DEFAULT_BG_COLOR_CODE) ? DEFAULT_FG_COLOR_CODE: bgcode]; 
						aColor = [aColor colorWithAlphaComponent: trans];
						[aColor set];
						NSRectFillUsingOperation(bgRect, hasBGImage?NSCompositeSourceOver:NSCompositeCopy);
					}
					bgstart = j; 
					bgcode = theLine[j].bg_color & 0x3ff; 
					fillBG = (bgcode & SELECTION_MASK) || (theLine[j].ch == 0 && (reversed || bgcode!=DEFAULT_BG_COLOR_CODE || !hasBGImage)) || (theLine[j].fg_color & BLINK_MASK && !blinkShow && (!hasBGImage ||bgcode!=DEFAULT_BG_COLOR_CODE));
				}
				
			}
*/
		}
		
		// finish pending jobs
		if (bgstart >= 0) 
		{
/*
			bgRect = NSMakeRect(floor(curX+bgstart*charWidth),curY-lineHeight,ceil((j-bgstart)*charWidth),lineHeight);
			// if we have a background image and we are using the background image, redraw image
			if (fillBG) {
				aColor = (bgcode & SELECTION_MASK) ? selectionColor : [self colorForCode: (reversed && bgcode == DEFAULT_BG_COLOR_CODE) ? DEFAULT_FG_COLOR_CODE: bgcode]; 
				aColor = [aColor colorWithAlphaComponent: trans];
				[aColor set];
				NSRectFillUsingOperation(bgRect, hasBGImage?NSCompositeSourceOver:NSCompositeCopy);
			}
*/
		}

		//draw all char
		for(j = 0; j < WIDTH; j++) 
		{
			out_hack = [out_hack stringByAppendingString:[NSString stringWithCharacters:&theLine[j].ch length:1]];

/*
			need_draw = (theLine[j].ch != 0xffff) && 
				(line < startScreenLineIndex || forceUpdate || dirty[j] || (theLine[j].fg_color & BLINK_MASK));
			if (need_draw) 
			{ 
				double_width = j<WIDTH-1 && (theLine[j+1].ch == 0xffff);

				if (reversed) {
					bgcode = theLine[j].bg_color == DEFAULT_BG_COLOR_CODE ? DEFAULT_FG_COLOR_CODE : theLine[j].bg_color;
				}
				else
					bgcode = theLine[j].bg_color;
				
				// switch colors if text is selected
				if((theLine[j].bg_color & SELECTION_MASK) && ((theLine[j].fg_color & 0x3ff) == DEFAULT_FG_COLOR_CODE))
					fgcode = SELECTED_TEXT | ((theLine[j].fg_color & BOLD_MASK) & 0x3ff); // check for bold
				else
					fgcode = (reversed && theLine[j].fg_color & DEFAULT_FG_COLOR_CODE) ? 
						(DEFAULT_BG_COLOR_CODE | (theLine[j].fg_color & BOLD_MASK)) : (theLine[j].fg_color & 0x3ff);
				
				if (blinkShow || !(theLine[j].fg_color & BLINK_MASK)) 
				{
					[self _drawCharacter:theLine[j].ch fgColor:fgcode bgColor:bgcode AtX:curX Y:curY doubleWidth: double_width];
					//draw underline
					if (theLine[j].fg_color & UNDER_MASK && theLine[j].ch) {
// TODO:
//						[[self colorForCode:(fgcode & 0x1ff)] set];
//						NSRectFill(NSMakeRect(curX,curY-2,charWidth,1));
					}
				}
			}
			if(line >= startScreenLineIndex) dirty[j]=0;
*/
			
			curX+=charWidth;
		}

    const unichar c = '\n';
    out_hack = [out_hack stringByAppendingString:[NSString stringWithCharacters:&c length:1]];

		curY+=lineHeight;
	}

  [out_hack drawInRect:rect 
              withStyle:@"font-family:CourierNewBold; font-size: 12px"];
	
	
    // Double check if dataSource is still available
/*
    if (!dataSource) return;
	
	x1=[dataSource cursorX]-1;
	y1=[dataSource cursorY]-1;
	
	//draw cursor	
	float cursorWidth, cursorHeight;				
				
	if(charWidth < charWidthWithoutSpacing)
		cursorWidth = charWidth;
	else
		cursorWidth = charWidthWithoutSpacing;
	
	if(lineHeight < charHeightWithoutSpacing)
		cursorHeight = lineHeight;
	else
		cursorHeight = charHeightWithoutSpacing;
	if (CURSOR) {
//		if([self blinkingCursor] && [[self window] isKeyWindow] && x1==oldCursorX && y1==oldCursorY)
		if([self blinkingCursor] && x1==oldCursorX && y1==oldCursorY)
			showCursor = blinkShow;
		else
			showCursor = YES;

		if (showCursor && x1<[dataSource width] && x1>=0 && y1>=0 && y1<[dataSource height]) {
			i = y1*[dataSource width]+x1;
			// get the cursor line
			theLine = [dataSource getLineAtScreenIndex: y1];
			
			//[[[self defaultCursorColor] colorWithAlphaComponent: trans] set];

			// TODO(allen): Draw a cursor

			ITermCursorType = CURSOR_VERTICAL;	
			switch ([[PreferencePanel sharedInstance] cursorType]) {
				case CURSOR_BOX:
					if([[self window] isKeyWindow])
					{
						NSRectFill(NSMakeRect(floor(x1 * charWidth + MARGIN),
											  (y1+[dataSource numberOfLines]-[dataSource height])*lineHeight + (lineHeight - cursorHeight),
											  ceil(cursorWidth), cursorHeight));
					}
					else
					{
						NSFrameRect(NSMakeRect(floor(x1 * charWidth + MARGIN),
											  (y1+[dataSource numberOfLines]-[dataSource height])*lineHeight + (lineHeight - cursorHeight),
											  ceil(cursorWidth), cursorHeight));
						
					}
					// draw any character on cursor if we need to
					unichar aChar = theLine[x1].ch;
					if (aChar)
					{
						if (aChar == 0xffff && x1>0) 
						{
							i--;
							x1--;
							aChar = theLine[x1].ch;
						}
						double_width = (x1 < WIDTH-1) && (theLine[x1+1].ch == 0xffff);
						[self _drawCharacter: aChar 
									 fgColor: [[self window] isKeyWindow]?CURSOR_TEXT:(theLine[x1].fg_color & 0x1ff)
									 bgColor: -1 // not to draw any background
										 AtX: x1 * charWidth + MARGIN 
										   Y: (y1+[dataSource numberOfLines]-[dataSource height]+1)*lineHeight
								 doubleWidth: double_width];
					}
						
					break;
				case CURSOR_VERTICAL:
					NSRectFill(NSMakeRect(floor(x1 * charWidth + MARGIN),
										  (y1+[dataSource numberOfLines]-[dataSource height])*lineHeight + (lineHeight - cursorHeight),
										  1, cursorHeight));
					break;
				case CURSOR_UNDERLINE:
					NSRectFill(NSMakeRect(floor(x1 * charWidth + MARGIN),
										  (y1+[dataSource numberOfLines]-[dataSource height]+1)*lineHeight + (lineHeight - cursorHeight) - 2,
										  ceil(cursorWidth), 2));
					break;
			}
					
			([dataSource dirty]+y1*WIDTH)[x1] = 1; //cursor loc is dirty
			
		}
	}
	
	oldCursorX = x1;
	oldCursorY = y1;
	
	// draw any text for NSTextInput
	if([self hasMarkedText]) {
		int len;
		
		len=[markedText length];
		if (len>[dataSource width]-x1) len=[dataSource width]-x1;
		[markedText drawInRect:NSMakeRect(floor(x1 * charWidth + MARGIN),
										  (y1+[dataSource numberOfLines]-[dataSource height])*lineHeight + (lineHeight - cursorHeight),
										  ceil((WIDTH-x1)*cursorWidth),cursorHeight)];
		memset([dataSource dirty]+y1*[dataSource width]+x1, 1,[dataSource width]-x1>len*2?len*2:[dataSource width]-x1); //len*2 is an over-estimation, but safe
	}
*/

	forceUpdate=NO;
    [dataSource releaseLock];
	
}
/*
- (void)keyDown:(NSEvent *)event
{
    NSInputManager *imana = [NSInputManager currentInputManager];
    BOOL IMEnable = [imana wantsToInterpretAllKeystrokes];
    id delegate = [self delegate];
	unsigned int modflag = [event modifierFlags];
    BOOL prev = [self hasMarkedText];
	
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView keyDown:%@]",
          __FILE__, __LINE__, event );
#endif
    
	keyIsARepeat = [event isARepeat];
	
    // Hide the cursor
    [NSCursor setHiddenUntilMouseMoves: YES];   
		
	if ([delegate hasKeyMappingForEvent: event highPriority: YES]) 
	{
		[delegate keyDown:event];
		return;
	}
	
    IM_INPUT_INSERT = NO;
    if (IMEnable) {
        [self interpretKeyEvents:[NSArray arrayWithObject:event]];
        
        if (prev == NO &&
            IM_INPUT_INSERT == NO &&
            [self hasMarkedText] == NO)
        {
            [delegate keyDown:event];
        }
    }
    else {
		// Check whether we have a custom mapping for this event or if numeric or function keys were pressed.
		if ( prev == NO && 
			 ([delegate hasKeyMappingForEvent: event highPriority: NO] ||
			  (modflag & NSNumericPadKeyMask) || 
			  (modflag & NSFunctionKeyMask)))
		{
			[delegate keyDown:event];
		}
		else {
			if([[self delegate] optionKey] == OPT_NORMAL)
			{
				[self interpretKeyEvents:[NSArray arrayWithObject:event]];
			}
			
			if (IM_INPUT_INSERT == NO) {
				[delegate keyDown:event];
			}
		}
    }
}
*/

- (BOOL) keyIsARepeat
{
	return (keyIsARepeat);
}
/*
- (void) otherMouseDown: (NSEvent *) event
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s: %@]", __PRETTY_FUNCTION__, sender );
#endif

    NSPoint locationInWindow, locationInTextView;
    locationInWindow = [event locationInWindow];
    locationInTextView = [self convertPoint: locationInWindow fromView: nil]; 
	
	NSRect visibleRect = [[self enclosingScrollView] documentVisibleRect];
	if (([[self delegate] xtermMouseReporting]) 
		&& (locationInTextView.y > visibleRect.origin.y) && !([event modifierFlags] & NSAlternateKeyMask))
		//		&& ([event modifierFlags] & NSCommandKeyMask == 0)) 
	{
		int rx, ry;
		rx = (locationInTextView.x-MARGIN - visibleRect.origin.x)/charWidth;
		ry = (locationInTextView.y - visibleRect.origin.y)/lineHeight;
		if (rx < 0) rx = -1;
		if (ry < 0) ry = -1;
		VT100Terminal *terminal = [dataSource terminal];
		PTYTask *task = [dataSource shellTask];

		int bnum = [event buttonNumber];
		if (bnum == 2) bnum = 1;
		
		switch ([terminal mouseMode]) {
			case MOUSE_REPORTING_NORMAL:
			case MOUSE_REPORTING_BUTTON_MOTION:
			case MOUSE_REPORTING_ALL_MOTION:
				reportingMouseDown = YES;
				[task writeTask:[terminal mousePress:bnum withModifiers:[event modifierFlags] atX:rx Y:ry]];
				return;
				break;
			case MOUSE_REPORTING_NONE:
			case MOUSE_REPORTING_HILITE:
				// fall through
				break;
		}
	}
	
	if([[PreferencePanel sharedInstance] pasteFromClipboard])
		[self paste: nil];
	else
		[self pasteSelection: nil];
}

- (void)otherMouseUp:(NSEvent *)event
{
	NSPoint locationInWindow, locationInTextView;
    locationInWindow = [event locationInWindow];
    locationInTextView = [self convertPoint: locationInWindow fromView: nil]; 
	
	NSRect visibleRect = [[self enclosingScrollView] documentVisibleRect];
	if (([[self delegate] xtermMouseReporting]) 
		&& reportingMouseDown && !([event modifierFlags] & NSAlternateKeyMask))
	{
		reportingMouseDown = NO;
		int rx, ry;
		rx = (locationInTextView.x-MARGIN - visibleRect.origin.x)/charWidth;
		ry = (locationInTextView.y - visibleRect.origin.y)/lineHeight;
		if (rx < 0) rx = -1;
		if (ry < 0) ry = -1;
		VT100Terminal *terminal = [dataSource terminal];
		PTYTask *task = [dataSource shellTask];
		
		switch ([terminal mouseMode]) {
			case MOUSE_REPORTING_NORMAL:
			case MOUSE_REPORTING_BUTTON_MOTION:
			case MOUSE_REPORTING_ALL_MOTION:
				[task writeTask:[terminal mouseReleaseAtX:rx Y:ry]];
				return;
				break;
			case MOUSE_REPORTING_NONE:
			case MOUSE_REPORTING_HILITE:
				// fall through
				break;
		}
	}	
	[super otherMouseUp:event];
}

- (void)otherMouseDragged:(NSEvent *)event
{
    NSPoint locationInWindow, locationInTextView;
    locationInWindow = [event locationInWindow];
    locationInTextView = [self convertPoint: locationInWindow fromView: nil]; 
	
	NSRect visibleRect = [[self enclosingScrollView] documentVisibleRect];
	if (([[self delegate] xtermMouseReporting]) 
		&& (locationInTextView.y > visibleRect.origin.y)
		&& reportingMouseDown && !([event modifierFlags] & NSAlternateKeyMask))
	{
		int rx, ry;
		rx = (locationInTextView.x-MARGIN - visibleRect.origin.x)/charWidth;
		ry = (locationInTextView.y - visibleRect.origin.y)/lineHeight;
		if (rx < 0) rx = -1;
		if (ry < 0) ry = -1;
		VT100Terminal *terminal = [dataSource terminal];
		PTYTask *task = [dataSource shellTask];
		
		int bnum = [event buttonNumber];
		if (bnum == 2) bnum = 1;
		
		switch ([terminal mouseMode]) {
			case MOUSE_REPORTING_NORMAL:
			case MOUSE_REPORTING_BUTTON_MOTION:
			case MOUSE_REPORTING_ALL_MOTION:
				[task writeTask:[terminal mouseMotion:bnum withModifiers:[event modifierFlags] atX:rx Y:ry]];
				return;
				break;
			case MOUSE_REPORTING_NONE:
			case MOUSE_REPORTING_HILITE:
				// fall through
				break;
		}
	}
	[super otherMouseDragged:event];
}

- (void) rightMouseDown: (NSEvent *) event
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s: %@]", __PRETTY_FUNCTION__, sender );
#endif
	
    NSPoint locationInWindow, locationInTextView;
    locationInWindow = [event locationInWindow];
    locationInTextView = [self convertPoint: locationInWindow fromView: nil]; 
	
	NSRect visibleRect = [[self enclosingScrollView] documentVisibleRect];
	if (([[self delegate] xtermMouseReporting]) 
		&& (locationInTextView.y > visibleRect.origin.y) && !([event modifierFlags] & NSAlternateKeyMask))
		//		&& ([event modifierFlags] & NSCommandKeyMask == 0)) 
	{
		int rx, ry;
		rx = (locationInTextView.x-MARGIN - visibleRect.origin.x)/charWidth;
		ry = (locationInTextView.y - visibleRect.origin.y)/lineHeight;
		if (rx < 0) rx = -1;
		if (ry < 0) ry = -1;
		VT100Terminal *terminal = [dataSource terminal];
		PTYTask *task = [dataSource shellTask];
		
		switch ([terminal mouseMode]) {
			case MOUSE_REPORTING_NORMAL:
			case MOUSE_REPORTING_BUTTON_MOTION:
			case MOUSE_REPORTING_ALL_MOTION:
				reportingMouseDown = YES;
				[task writeTask:[terminal mousePress:2 withModifiers:[event modifierFlags] atX:rx Y:ry]];
				return;
				break;
			case MOUSE_REPORTING_NONE:
			case MOUSE_REPORTING_HILITE:
				// fall through
				break;
		}
	}
	[super rightMouseDown:event];
}

- (void)rightMouseUp:(NSEvent *)event
{
	NSPoint locationInWindow, locationInTextView;
    locationInWindow = [event locationInWindow];
    locationInTextView = [self convertPoint: locationInWindow fromView: nil]; 
	
	NSRect visibleRect = [[self enclosingScrollView] documentVisibleRect];
	if (([[self delegate] xtermMouseReporting]) 
		&& reportingMouseDown && !([event modifierFlags] & NSAlternateKeyMask))
	{
		reportingMouseDown = NO;
		int rx, ry;
		rx = (locationInTextView.x-MARGIN - visibleRect.origin.x)/charWidth;
		ry = (locationInTextView.y - visibleRect.origin.y)/lineHeight;
		if (rx < 0) rx = -1;
		if (ry < 0) ry = -1;
		VT100Terminal *terminal = [dataSource terminal];
		PTYTask *task = [dataSource shellTask];
		
		switch ([terminal mouseMode]) {
			case MOUSE_REPORTING_NORMAL:
			case MOUSE_REPORTING_BUTTON_MOTION:
			case MOUSE_REPORTING_ALL_MOTION:
				[task writeTask:[terminal mouseReleaseAtX:rx Y:ry]];
				return;
				break;
			case MOUSE_REPORTING_NONE:
			case MOUSE_REPORTING_HILITE:
				// fall through
				break;
		}
	}	
	[super rightMouseUp:event];
}

- (void)rightMouseDragged:(NSEvent *)event
{
    NSPoint locationInWindow, locationInTextView;
    locationInWindow = [event locationInWindow];
    locationInTextView = [self convertPoint: locationInWindow fromView: nil]; 
	
	NSRect visibleRect = [[self enclosingScrollView] documentVisibleRect];
	if (([[self delegate] xtermMouseReporting]) 
		&& (locationInTextView.y > visibleRect.origin.y)
		&& reportingMouseDown && !([event modifierFlags] & NSAlternateKeyMask))
	{
		int rx, ry;
		rx = (locationInTextView.x-MARGIN - visibleRect.origin.x)/charWidth;
		ry = (locationInTextView.y - visibleRect.origin.y)/lineHeight;
		if (rx < 0) rx = -1;
		if (ry < 0) ry = -1;
		VT100Terminal *terminal = [dataSource terminal];
		PTYTask *task = [dataSource shellTask];
		
		switch ([terminal mouseMode]) {
			case MOUSE_REPORTING_NORMAL:
			case MOUSE_REPORTING_BUTTON_MOTION:
			case MOUSE_REPORTING_ALL_MOTION:
				[task writeTask:[terminal mouseMotion:2 withModifiers:[event modifierFlags] atX:rx Y:ry]];
				return;
				break;
			case MOUSE_REPORTING_NONE:
			case MOUSE_REPORTING_HILITE:
				// fall through
				break;
		}
	}
	[super rightMouseDragged:event];
}

- (void)scrollWheel:(NSEvent *)event
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s: %@]", __PRETTY_FUNCTION__, sender );
#endif
	
    NSPoint locationInWindow, locationInTextView;
    locationInWindow = [event locationInWindow];
    locationInTextView = [self convertPoint: locationInWindow fromView: nil]; 
	
	NSRect visibleRect = [[self enclosingScrollView] documentVisibleRect];
	if (([[self delegate] xtermMouseReporting]) 
		&& (locationInTextView.y > visibleRect.origin.y) && !([event modifierFlags] & NSAlternateKeyMask))
		//		&& ([event modifierFlags] & NSCommandKeyMask == 0)) 
	{
		int rx, ry;
		rx = (locationInTextView.x-MARGIN - visibleRect.origin.x)/charWidth;
		ry = (locationInTextView.y - visibleRect.origin.y)/lineHeight;
		if (rx < 0) rx = -1;
		if (ry < 0) ry = -1;
		VT100Terminal *terminal = [dataSource terminal];
		PTYTask *task = [dataSource shellTask];
		
		switch ([terminal mouseMode]) {
			case MOUSE_REPORTING_NORMAL:
			case MOUSE_REPORTING_BUTTON_MOTION:
			case MOUSE_REPORTING_ALL_MOTION:
				[task writeTask:[terminal mousePress:([event deltaY] > 0 ? 5:4) withModifiers:[event modifierFlags] atX:rx Y:ry]];
				return;
				break;
			case MOUSE_REPORTING_NONE:
			case MOUSE_REPORTING_HILITE:
				// fall through
				break;
		}
	}
	
	[super scrollWheel:event];	
}

- (void)mouseExited:(NSEvent *)event
{
	//NSLog(@"%s: 0x%x", __PRETTY_FUNCTION__, self);
	// no-op
}

- (void)mouseEntered:(NSEvent *)event
{
	//NSLog(@"%s: 0x%x", __PRETTY_FUNCTION__, self);
	
	if([[PreferencePanel sharedInstance] focusFollowsMouse])
		[[self window] makeKeyWindow];
}

- (void)mouseDown:(NSEvent *)event
{
	
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView mouseDown:%@]",
          __FILE__, __LINE__, event );
#endif
    
    NSPoint locationInWindow, locationInTextView;
    int x, y;
    int width = [dataSource width];
	
    locationInWindow = [event locationInWindow];
    locationInTextView = [self convertPoint: locationInWindow fromView: nil]; 
    
    x = (locationInTextView.x-MARGIN)/charWidth;
	if (x<0) x=0;
    y = locationInTextView.y/lineHeight;
	
    if (x>=width) x = width  - 1;

	NSRect visibleRect = [[self enclosingScrollView] documentVisibleRect];
	if (([[self delegate] xtermMouseReporting]) 
		&& (locationInTextView.y > visibleRect.origin.y) && !([event modifierFlags] & NSAlternateKeyMask))
	{
		int rx, ry;
		rx = (locationInTextView.x-MARGIN - visibleRect.origin.x)/charWidth;
		ry = (locationInTextView.y - visibleRect.origin.y)/lineHeight;
		if (rx < 0) rx = -1;
		if (ry < 0) ry = -1;
		VT100Terminal *terminal = [dataSource terminal];
		PTYTask *task = [dataSource shellTask];
		
		switch ([terminal mouseMode]) {
			case MOUSE_REPORTING_NORMAL:
			case MOUSE_REPORTING_BUTTON_MOTION:
			case MOUSE_REPORTING_ALL_MOTION:
				reportingMouseDown = YES;
				[task writeTask:[terminal mousePress:0 withModifiers:[event modifierFlags] atX:rx Y:ry]];
				return;
				break;
			case MOUSE_REPORTING_NONE:
			case MOUSE_REPORTING_HILITE:
				// fall through
				break;
		}
	}
	
	if(mouseDownEvent != nil)
    {
		[mouseDownEvent release];
		mouseDownEvent = nil;
    }	
    [event retain];
    mouseDownEvent = event;
	
	
	mouseDragged = NO;
	mouseDown = YES;
	mouseDownOnSelection = NO;
    
    if ([event clickCount]<2 ) {
        selectMode = SELECT_CHAR;

        // if we are holding the shift key down, we are extending selection
        if (startX > -1 && ([event modifierFlags] & NSShiftKeyMask))
        {
            if (x+y*width<startX+startY*width) {
                startX = endX;
                startY = endY;
            }
            endX = x;
            endY = y;
        }
		// check if we clicked inside a selection for a possible drag
		else if(startX > -1 && [self _mouseDownOnSelection: event] == YES)
		{
			mouseDownOnSelection = YES;
			[super mouseDown: event];
			return;
		}
        else if (!([event modifierFlags] & NSCommandKeyMask))
        {
            endX = startX = x;
            endY = startY = y;
        }	
    }
	// Handle double and triple click
	else if([event clickCount] == 2)
	{
        int tmpX1, tmpY1, tmpX2, tmpY2;
        
        // double-click; select word
        selectMode = SELECT_WORD;
		NSString *selectedWord = [self _getWordForX: x y: y startX: &tmpX1 startY: &tmpY1 endX: &tmpX2 endY: &tmpY2];
		if ([self _findMatchingParenthesis:selectedWord withX:tmpX1 Y:tmpY1]) {
			;
		}
		else if (startX > -1 && ([event modifierFlags] & NSShiftKeyMask))
        {
            if (startX+startY*width<tmpX1+tmpY1*width) {
                endX = tmpX2;
                endY = tmpY2;	
            }
            else {
                startX = endX;
                startY = endY;
                endX = tmpX1;
                endY = tmpY1;
            }
        }
        else 
        {
            startX = tmpX1;
            startY = tmpY1;
            endX = tmpX2;
            endY = tmpY2;	
        }
	}
	else if ([event clickCount] >= 3)
	{
        // triple-click; select line
        selectMode = SELECT_LINE;
        if (startX > -1 && ([event modifierFlags] & NSShiftKeyMask))
        {
            if (startY<y) {
                endX = width - 1;
                endY = y;
            }
            else {
                if (startX+startY*width<endX+endY*width) {
                    startX = endX;
                    startY = endY;
                }
                endX = 0;
                endY = y;
            }
        }
        else
        {
            startX = 0;
            endX = width - 1;
            startY = endY = y;
        }            
	}
	    
    if (startX>-1 && (startX != endX || startY!=endY)) 
        [self _selectFromX:startX Y:startY toX:endX Y:endY];

    if([_delegate respondsToSelector: @selector(willHandleEvent:)] && [_delegate willHandleEvent: event])
        [_delegate handleEvent: event];
	[self setNeedsDisplay];
	
}

- (void)mouseUp:(NSEvent *)event
{	
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView mouseUp:%@]",
          __FILE__, __LINE__, event );
#endif
	NSPoint locationInWindow = [event locationInWindow];
    NSPoint locationInTextView = [self convertPoint: locationInWindow fromView: nil];
	int x, y;
	int width = [dataSource width];
	
    x = (locationInTextView.x - MARGIN) / charWidth;
	if (x < 0) x = 0;
	if (x>=width) x = width - 1;
	
    
	y = locationInTextView.y/lineHeight;
	
	
	if ([[self delegate] xtermMouseReporting]
		&& reportingMouseDown && !([event modifierFlags] & NSAlternateKeyMask)) 
	{
		reportingMouseDown = NO;
		int rx, ry;
		NSRect visibleRect = [[self enclosingScrollView] documentVisibleRect];
		rx = (locationInTextView.x-MARGIN - visibleRect.origin.x)/charWidth;
		ry = (locationInTextView.y - visibleRect.origin.y)/lineHeight;
		if (rx < 0) rx = -1;
		if (ry < 0) ry = -1;
		VT100Terminal *terminal = [dataSource terminal];
		PTYTask *task = [dataSource shellTask];
		
		switch ([terminal mouseMode]) {
			case MOUSE_REPORTING_NORMAL:
			case MOUSE_REPORTING_BUTTON_MOTION:
			case MOUSE_REPORTING_ALL_MOTION:
				[task writeTask:[terminal mouseReleaseAtX:rx Y:ry]];
				return;
				break;
			case MOUSE_REPORTING_NONE:
			case MOUSE_REPORTING_HILITE:
				// fall through
				break;
		}
	}
	
	if(mouseDown == NO)
		return;
	mouseDown = NO;
		
	// make sure we have key focus
	[[self window] makeFirstResponder: self];
    
    if (startY>endY||(startY==endY&&startX>endX)) {
        int t;
        t=startY; startY=endY; endY=t;
        t=startX; startX=endX; endX=t;
    }
    else if ([mouseDownEvent locationInWindow].x == [event locationInWindow].x &&
			 [mouseDownEvent locationInWindow].y == [event locationInWindow].y && 
			 !([event modifierFlags] & NSShiftKeyMask) &&
			 [event clickCount] < 2 && !mouseDragged) 
	{		
		startX=-1;
        
        if(([event modifierFlags] & NSCommandKeyMask) && [[PreferencePanel sharedInstance] cmdSelection] &&
           [mouseDownEvent locationInWindow].x == [event locationInWindow].x &&
           [mouseDownEvent locationInWindow].y == [event locationInWindow].y)
        {
            //[self _openURL: [self selectedText]];
			NSString *url = [self _getURLForX:x y:y];
            if (url != nil) [self _openURL:url];
        }
	}
	
	// if we are on an empty line, we select the current line to the end
	//if([self _isBlankLine: y] && y >= 0)
	//  endX = [dataSource width] - 1;
	
	
	[self _selectFromX:startX Y:startY toX:endX Y:endY];
    if (startX!=-1&&_delegate) {
		// if we want to copy our selection, do so
        if([[PreferencePanel sharedInstance] copySelection])
            [self copy: self];
        // handle command click on URL
    }
	
    selectMode = SELECT_CHAR;
	[self setNeedsDisplay];
}

- (void)mouseDragged:(NSEvent *)event
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView mouseDragged:%@; modifier flags = 0x%x]",
          __FILE__, __LINE__, event, [event modifierFlags] );
#endif
    NSPoint locationInWindow = [event locationInWindow];
    NSPoint locationInTextView = [self convertPoint: locationInWindow fromView: nil];
    NSRect  rectInTextView = [self visibleRect];
    int x, y, tmpX1, tmpX2, tmpY1, tmpY2;
    int width = [dataSource width];
	NSString *theSelectedText;
	
    x = (locationInTextView.x - MARGIN) / charWidth;
	if (x < 0) x = 0;
	if (x>=width) x = width - 1;
	
    
	y = locationInTextView.y/lineHeight;
	
	if (([[self delegate] xtermMouseReporting])
		&& reportingMouseDown&& !([event modifierFlags] & NSAlternateKeyMask)) 
	{
		int rx, ry;
		NSRect visibleRect = [[self enclosingScrollView] documentVisibleRect];
		rx = (locationInTextView.x-MARGIN - visibleRect.origin.x)/charWidth;
		ry = (locationInTextView.y - visibleRect.origin.y)/lineHeight;
		if (rx < 0) rx = -1;
		if (ry < 0) ry = -1;
		VT100Terminal *terminal = [dataSource terminal];
		PTYTask *task = [dataSource shellTask];
		
		switch ([terminal mouseMode]) {
			case MOUSE_REPORTING_BUTTON_MOTION:
			case MOUSE_REPORTING_ALL_MOTION:
				[task writeTask:[terminal mouseMotion:0 withModifiers:[event modifierFlags] atX:rx Y:ry]];
			case MOUSE_REPORTING_NORMAL:
				return;
				break;
			case MOUSE_REPORTING_NONE:
			case MOUSE_REPORTING_HILITE:
				// fall through
				break;
		}
	}
	
	mouseDragged = YES;
	
	// check if we want to drag and drop a selection
	if(mouseDownOnSelection == YES && ([event modifierFlags] & NSCommandKeyMask))
	{
		theSelectedText = [self contentFromX: startX Y: startY ToX: endX Y: endY pad: NO];
		if([theSelectedText length] > 0)
		{
			[self _dragText: theSelectedText forEvent: event];
			return;
		}
	}
    
	// NSLog(@"(%f,%f)->(%f,%f)",locationInWindow.x,locationInWindow.y,locationInTextView.x,locationInTextView.y); 
    if (locationInTextView.y<rectInTextView.origin.y) {
        rectInTextView.origin.y=locationInTextView.y;
        [self scrollRectToVisible: rectInTextView];
    }
    else if (locationInTextView.y>rectInTextView.origin.y+rectInTextView.size.height) {
        rectInTextView.origin.y+=locationInTextView.y-rectInTextView.origin.y-rectInTextView.size.height;
        [self scrollRectToVisible: rectInTextView];
    }
    
	// if we are on an empty line, we select the current line to the end
	if(y>=0 && [self _isBlankLine: y])
		x = width - 1;
	
	if(locationInTextView.x < MARGIN && startY < y)
	{
		// complete selection of previous line
		x = width - 1;
		y--;
	}
    if (y<0) y=0;
    if (y>=[dataSource numberOfLines]) y=numberOfLines - 1;
    
    switch (selectMode) {
        case SELECT_CHAR:
            endX=x;
            endY=y;
            break;
        case SELECT_WORD:
            [self _getWordForX: x y: y startX: &tmpX1 startY: &tmpY1 endX: &tmpX2 endY: &tmpY2];
            if (startX+startY*width<tmpX2+tmpY2*width) {
                if (startX+startY*width>endX+endY*width) {
                    int tx1, tx2, ty1, ty2;
                    [self _getWordForX: startX y: startY startX: &tx1 startY: &ty1 endX: &tx2 endY: &ty2];
                    startX = tx1;
                    startY = ty1;
                }
                endX = tmpX2;
                endY = tmpY2;
            }
            else {
                if (startX+startY*width<endX+endY*width) {
                    int tx1, tx2, ty1, ty2;
                    [self _getWordForX: startX y: startY startX: &tx1 startY: &ty1 endX: &tx2 endY: &ty2];
                    startX = tx2;
                    startY = ty2;
                }
                endX = tmpX1;
                endY = tmpY1;
            }
            break;
        case SELECT_LINE:
            if (startY <= y) {
                startX = 0;
                endX = [dataSource width] - 1;
                endY = y;
            }
            else {
                endX = 0;
                endY = y;
                startX = [dataSource width] - 1;
            }
            break;
    }
            
    [self _selectFromX:startX Y:startY toX:endX Y:endY];
	[self setNeedsDisplay];
	//NSLog(@"(%d,%d)-(%d,%d)",startX,startY,endX,endY);
}
*/


- (NSString *) contentFromX:(int)startx Y:(int)starty ToX:(int)endx Y:(int)endy pad: (BOOL) pad
{
	unichar *temp;
	int j;
	int width, y, x1, x2;
	NSString *str;
	screen_char_t *theLine;
	BOOL endOfLine;
	int i;
	
	width = [dataSource width];
	temp = (unichar *) malloc(((endy-starty+1)*(width+1)+(endx-startx+1))*sizeof(unichar));
	j = 0;
	for (y = starty; y <= endy; y++) 
	{
		theLine = [dataSource getLineAtIndex:y];

		x1 = y == starty ? startx : 0;
		x2 = y == endy ? endx : width-1;
		for(; x1 <= x2; x1++) 
		{
			if (theLine[x1].ch != 0xffff) 
			{
				temp[j] = theLine[x1].ch;
				if(theLine[x1].ch == 0) // end of line?
				{
					// if there is no text after this, insert a hard line break
					endOfLine = YES;
					for(i = x1+1; i <= x2 && endOfLine; i++)
					{
						if(theLine[i].ch != 0)
							endOfLine = NO;
					}
					if (endOfLine) {
						if (pad) {
							for(i = x1; i <= x2; i++) temp[j++] = ' ';
						}
						if (y < endy && !theLine[width].ch){
							temp[j] = '\n'; // hard break
							j++;
							break; // continue to next line
						}
						break;
					}
					else
						temp[j] = ' '; // represent blank with space
				}
				else if (x1 == x2 && y < endy && !theLine[width].ch) // definitely end of line
				{
					temp[++j] = '\n'; // hard break
				}
				j++;
			}
		}		
	}
	
	str=[NSString stringWithCharacters:temp length:j];
	free(temp);
	
	return str;
}
/// NSTextInput stuff

- (void)insertText:(id)aString
{
NSLog(@"insertText shouldn't be called?");
exit(1);
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView insertText:%@]",
          __FILE__, __LINE__, aString);
#endif
   /* 
    if ([self hasMarkedText]) {
        IM_INPUT_MARKEDRANGE = NSMakeRange(0, 0);
        [markedText release];
		markedText=nil;
    }
*/
/*
    if ([(NSString*)aString length]>0) {
        if ([_delegate respondsToSelector:@selector(insertText:)])
            [_delegate insertText:aString];
        else
            [super insertText:aString];

        IM_INPUT_INSERT = YES;
    }
*/
}
/*
- (void)setMarkedText:(id)aString selectedRange:(NSRange)selRange
{
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView setMarkedText:%@ selectedRange:(%d,%d)]",
          __FILE__, __LINE__, aString, selRange.location, selRange.length);
#endif
	[markedText release];
    if ([aString isKindOfClass:[NSAttributedString class]]) {
        markedText=[[NSAttributedString alloc] initWithString:[aString string] attributes:[self markedTextAttributes]];
    }
    else {
        markedText=[[NSAttributedString alloc] initWithString:aString attributes:[self markedTextAttributes]];
    }
	IM_INPUT_MARKEDRANGE = NSMakeRange(0,[markedText length]);
    IM_INPUT_SELRANGE = selRange;
	[self setNeedsDisplay];
}

- (void)unmarkText
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView unmarkText]", __FILE__, __LINE__ );
#endif
    IM_INPUT_MARKEDRANGE = NSMakeRange(0, 0);
}

- (BOOL)hasMarkedText
{
    BOOL result;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView hasMarkedText]", __FILE__, __LINE__ );
#endif
    if (IM_INPUT_MARKEDRANGE.length > 0)
        result = YES;
    else
        result = NO;
    
    return result;
}

- (NSRange)markedRange
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView markedRange]", __FILE__, __LINE__);
#endif
    
    //return IM_INPUT_MARKEDRANGE;
    if (IM_INPUT_MARKEDRANGE.length > 0) {
        return NSMakeRange([dataSource cursorX]-1, IM_INPUT_MARKEDRANGE.length);
    }
    else
        return NSMakeRange([dataSource cursorX]-1, 0);
}

- (NSRange)selectedRange
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView selectedRange]", __FILE__, __LINE__);
#endif
    return NSMakeRange(NSNotFound, 0);
}

- (NSArray *)validAttributesForMarkedText
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView validAttributesForMarkedText]", __FILE__, __LINE__);
#endif
    return [NSArray arrayWithObjects:NSForegroundColorAttributeName,
        NSBackgroundColorAttributeName,
        NSUnderlineStyleAttributeName,
		NSFontAttributeName,
        nil];
}

- (NSAttributedString *)attributedSubstringFromRange:(NSRange)theRange
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView attributedSubstringFromRange:(%d,%d)]", __FILE__, __LINE__, theRange.location, theRange.length);
#endif
	
    return [markedText attributedSubstringFromRange:NSMakeRange(0,theRange.length)];
}

- (unsigned int)characterIndexForPoint:(NSPoint)thePoint
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView characterIndexForPoint:(%f,%f)]", __FILE__, __LINE__, thePoint.x, thePoint.y);
#endif
    
    return thePoint.x/charWidth;
}

- (long)conversationIdentifier
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView conversationIdentifier]", __FILE__, __LINE__);
#endif
    return (long)self; //not sure about this
}

- (NSRect)firstRectForCharacterRange:(NSRange)theRange
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView firstRectForCharacterRange:(%d,%d)]", __FILE__, __LINE__, theRange.location, theRange.length);
#endif
    int y=[dataSource cursorY]-1;
    int x=[dataSource cursorX]-1;
    
    NSRect rect=NSMakeRect(x*charWidth+MARGIN,(y+[dataSource numberOfLines] - [dataSource height]+1)*lineHeight,charWidth*theRange.length,lineHeight);
    //NSLog(@"(%f,%f)",rect.origin.x,rect.origin.y);
    rect.origin=[[self window] convertBaseToScreen:[self convertPoint:rect.origin toView:nil]];
    //NSLog(@"(%f,%f)",rect.origin.x,rect.origin.y);
    
    return rect;
}

- (void) findString: (NSString *) aString forwardDirection: (BOOL) direction ignoringCase: (BOOL) ignoreCase
{
	BOOL foundString;
	int tmpX, tmpY;
	
	foundString = [self _findString: aString forwardDirection: direction ignoringCase: ignoreCase wrapping:YES];
	if(foundString == NO)
	{
		// start from beginning or end depending on search direction
		tmpX = lastFindX;
		tmpY = lastFindY;
		lastFindX = lastFindY = -1;
		foundString = [self _findString: aString forwardDirection: direction ignoringCase: ignoreCase wrapping:YES];
		if(foundString == NO)
		{
			lastFindX = tmpX;
			lastFindY = tmpY;
		}
	}
	
}
*/
/*
// transparency
- (float) transparency
{
	return (transparency);
}

- (void) setTransparency: (float) fVal
{
	transparency = fVal;
	forceUpdate = YES;
	useTransparency = fVal >=0.01;
	[self setNeedsDisplay];
	[self resetCharCache];
}

- (BOOL) useTransparency
{
  return useTransparency;
}

- (void) setUseTransparency: (BOOL) flag
{
  useTransparency = flag;
  forceUpdate = YES;
  [self setNeedsDisplay];
  [self resetCharCache];
}
*/

// service stuff
/*
- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType
{
	//NSLog(@"%s: %@, %@", __PRETTY_FUNCTION__, sendType, returnType);
	
	if(sendType != nil && [sendType isEqualToString: NSStringPboardType])
		return (self);
	
	return ([super validRequestorForSendType: sendType returnType: returnType]);
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types
{
	//NSLog(@"%s", __PRETTY_FUNCTION__);
    NSString *copyString;
        
    copyString=[self selectedText];
    
    if (copyString && [copyString length]>0) {
        [pboard declareTypes: [NSArray arrayWithObject: NSStringPboardType] owner: self];
        [pboard setString: copyString forType: NSStringPboardType];
		return (YES);
    }
	
	return (NO);
}

- (BOOL)readSelectionFromPasteboard:(NSPasteboard *)pboard
{
	//NSLog(@"%s", __PRETTY_FUNCTION__);
	return (NO);
}

*/
@end

//
// private methods
//
@implementation PTYTextView (Private)
/*
- (void) _renderChar:(NSImage *)image withChar:(unichar) carac withColor:(NSColor*)color withBGColor:(NSColor*)bgColor //withFont:(NSFont*)aFont bold:(int)bold
{
	NSString  *crap;
	NSDictionary *attrib;
//	NSFont *theFont;
	float sw;
	BOOL renderBold;
 	BOOL tigerOrLater = YES;
//	BOOL tigerOrLater = (NSAppKitVersionNumber > NSAppKitVersionNumber10_3);
//	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	
	//NSLog(@"%s: drawing char %c", __PRETTY_FUNCTION__, carac);
	//NSLog(@"%@",NSStrokeWidthAttributeName);

// TODO: font and bold	
//	theFont = aFont;
	renderBold = false;  //bold && ![self disableBold];
	
	if(renderBold)
	{
		theFont = [fontManager convertFont: aFont toHaveTrait: NSBoldFontMask];
		
        // Check if there is native bold support
		// if conversion was successful, else use our own methods to convert to bold
		if ([fontManager traitsOfFont:theFont] & NSBoldFontMask) 
		{
			sw = antiAlias ? strokeWidth:0;
			renderBold = NO;
		}
		else
		{
			sw = antiAlias? boldStrokeWidth : 0;
			theFont = aFont;
		}
	}
    else 
    {
        sw = antiAlias ? strokeWidth:0;
    } 
	if (tigerOrLater && sw)
	{
		attrib=[NSDictionary dictionaryWithObjectsAndKeys:
			theFont, NSFontAttributeName,
			color, NSForegroundColorAttributeName,
			[NSNumber numberWithFloat: sw], @"NSStrokeWidth",
			nil];
	}
	else
	{
		attrib=[NSDictionary dictionaryWithObjectsAndKeys:
			theFont, NSFontAttributeName,
			color, NSForegroundColorAttributeName,
			nil];		
	}

	crap = [NSString stringWithCharacters:&carac length:1];		
	[image lockFocus];
	[[NSGraphicsContext currentContext] setShouldAntialias: antiAlias];
	if (bgColor) {
		bgColor = [bgColor colorWithAlphaComponent: (useTransparency ? 1.0 - transparency : 1.0)];
		[bgColor set];
		NSRectFill(NSMakeRect(0,0,[image size].width,[image size].height));
	}
	[crap drawAtPoint:NSMakePoint(0,0) withAttributes:attrib];
	
	// on older systems, for bold, redraw the character offset by 1 pixel
	if (renderBold && (!tigerOrLater || !antiAlias))
	{
		[crap drawAtPoint:NSMakePoint(1,0)  withAttributes:attrib];
	}
	[image unlockFocus];
} // renderChar

#define  CELLSIZE (cacheSize/256)
- (NSImage *) _getCharImage:(unichar) code color:(unsigned int)fg bgColor:(unsigned int)bg doubleWidth:(BOOL) dw
{
	int i;
	int j;
	NSImage *image;
	unsigned int c = fg;
	unsigned short int seed[3];
	
	if (fg == SELECTED_TEXT) {
		c = SELECTED_TEXT;
	}
	else if (fg == CURSOR_TEXT) {
		c = CURSOR_TEXT;
	}
	else {
		c &= 0x3ff; // turn of all masks except for bold and default fg color
	}
	if (!code) return nil;
	if (code>=0x20 && code<0x7f && c == DEFAULT_FG_COLOR_CODE && bg == DEFAULT_BG_COLOR_CODE) {
		i = code - 0x20;
		j = 0;
	}
	else {
		seed[0]=code; seed[1] = c; seed[2] = bg;
		i = nrand48(seed) % (cacheSize-CELLSIZE-0x5f) + 0x5f;
		//srand( code<<16 + c<<8 + bg);
		//i = rand() % (CACHESIZE-CELLSIZE);
		for(j = 0;(charImages[i].code!=code || charImages[i].color!=c || charImages[i].bgColor != bg) && charImages[i].image && j<CELLSIZE; i++, j++);
	}
	if (!charImages[i].image) {
		//  NSLog(@"add into cache");
		image=charImages[i].image=[[NSImage alloc]initWithSize:NSMakeSize(charWidth*(dw?2:1), lineHeight)];
		charImages[i].code=code;
		charImages[i].color=c;
		charImages[i].bgColor=bg;
		charImages[i].count=1;
		[self _renderChar: image 
				withChar: code
			   withColor: [self colorForCode: c]
			  withBGColor: (bg == -1 ? nil : [self colorForCode: bg])];

				withFont: dw?nafont:font
					bold: c&BOLD_MASK];
		return image;
	}
	else if (j>=CELLSIZE) {
		// NSLog(@"new char, but cache full (%d, %d, %d)", code, c, i);
		int t=1;
		for(j=2; j<=CELLSIZE; j++) {	//find a least used one, and replace it with new char
			if (charImages[i-j].count < charImages[i-t].count) t = j;
		}
		t = i - t;
		[charImages[t].image release];
		image=charImages[t].image=[[NSImage alloc]initWithSize:NSMakeSize(charWidth*(dw?2:1), lineHeight)];
		charImages[t].code=code;
		charImages[i].bgColor=bg;
		charImages[t].color=c;
		for(j=1; j<=CELLSIZE; j++) {	//reset the cache count
			charImages[i-j].count -= charImages[t].count;
		}
		charImages[t].count=1;
		
		[self _renderChar: image 
				withChar: code
			   withColor: [self colorForCode: c & 0x1ff] //turn off bold mask
			  withBGColor: (bg == -1 ? nil : [self colorForCode: bg])
				withFont: dw?nafont:font
					bold: c & BOLD_MASK];
		return image;
	}
	else {
		//		NSLog(@"already in cache");
		charImages[i].count++;
		return charImages[i].image;
	}
	
}
*/

- (void) _drawCharacter:(unichar)c fgColor:(int)fg bgColor:(int)bg AtX:(float)X Y:(float)Y doubleWidth:(BOOL) dw
{
	NSLog(@"drawCharacter: %c", c);
//	NSImage *image;
//	BOOL bgImage = ([(PTYScrollView *)[self enclosingScrollView] backgroundImage] != nil);
//	BOOL noBg = bg==-1 || (bg&SELECTION_MASK) || (bgImage && bg == DEFAULT_BG_COLOR_CODE);
		
	if (c) {
		NSLog(@"%s: %c(%d)",__PRETTY_FUNCTION__, c,c);

	int x, y;
	x = X * 5;
	y = Y * 21;
// TODO: Color
	NSString* crap = [NSString stringWithCharacters:&c length:1];
	[crap drawInRect:CGRectMake(X, Y, X + 5, Y + 12)
               withStyle:@"font-family:CourierNewBold; font-size: 12px"];
/*
		image=[self _getCharImage:c 
						   color:fg
						  bgColor:noBg ? -1: bg
					 doubleWidth:dw];
		
		[image compositeToPoint:NSMakePoint(X,Y) operation: bgImage || (bg&SELECTION_MASK) || bg==-1 ? NSCompositeSourceOver:NSCompositeCopy];
*/
	}

}	

- (void) _scrollToLine:(int)line
{
	CGRect aFrame;
	aFrame.origin.x = 0;
	aFrame.origin.y = line * lineHeight;
	aFrame.size.width = [self frame].size.width;
	aFrame.size.height = lineHeight;
	forceUpdate = YES;
	[self scrollRectToVisible: aFrame];
}


- (void) _selectFromX:(int)startx Y:(int)starty toX:(int)endx Y:(int)endy
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView _selectFromX:%d Y:%d toX:%d Y:%d]", __FILE__, __LINE__, startx, starty, endx, endy);
#endif

	int bfHeight;
	int width, height, x, y, idx, startIdx, endIdx;
	unsigned int newbg;
	char *dirty;
	screen_char_t *theLine;
	
	width = [dataSource width];
	height = [dataSource numberOfLines];
	bfHeight = height - [dataSource height];
	if (startX == -1) startIdx = endIdx = width*height+1;
	else {
		startIdx = startx + starty * width;
		endIdx = endx + endy * width;
		if (startIdx > endIdx) {
			idx = startIdx;
			startIdx = endIdx;
			endIdx = idx;
		}
	}
	
	for (idx=y=0; y<height; y++) {
		theLine = [dataSource getLineAtIndex: y];
		
		if (y < bfHeight) 
		{
			dirty = NULL;
		} 
		else 
		{
			dirty = [dataSource dirty] + (y - bfHeight) * width;
		}
		for(x=0; x < width; x++, idx++) 
		{
			if (idx >= startIdx && idx<=endIdx) 
				newbg = theLine[x].bg_color | SELECTION_MASK;
			else
				newbg = theLine[x].bg_color & ~SELECTION_MASK;
			if (newbg != theLine[x].bg_color) 
			{
				theLine[x].bg_color = newbg;
				if (dirty) dirty[x] = 1;
			}
		}		
	}
}
/*
- (void) _updateSelectionLocation
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView _selectFromX:%d Y:%d toX:%d Y:%d]", __FILE__, __LINE__, startx, starty, endx, endy);
#endif
	
	int width, height, x, y;
	screen_char_t *theLine;
	BOOL foundSelection = NO;
	
	if (startX < 0) return;
	
	width = [dataSource width];
	height = [dataSource numberOfLines];
	for (y=0; y<height; y++) {
		theLine = [dataSource getLineAtIndex: y];
		
		for(x=0; x < width; x++) 
		{
			if (theLine[x].bg_color & SELECTION_MASK) {
				if (!foundSelection) {
					startX = x;
					startY = y;
					foundSelection = YES;
				}
			}
			else if (foundSelection) {
				endX = x - 1;
				endY = y;
				if (endX < 0) {
					endX = width - 1;
					endY --;
				}
				return;
			}
		}		
	}
	if (foundSelection) {
		endX = width - 1;
		endY = height - 1;
	}
	else {
		startX=-1;
	}
	
	return;
		
}
*/

- (unichar) _getCharacterAtX:(int) x Y:(int) y
{
	screen_char_t *theLine;
	theLine = [dataSource getLineAtIndex:y];
		
	return theLine[x].ch;
}

/*
- (NSString *) _getWordForX: (int) x 
                          y: (int) y 
                     startX: (int *) startx 
                     startY: (int *) starty 
                       endX: (int *) endx 
                       endY: (int *) endy
{
	NSString *aString,*wordChars;
	int tmpX, tmpY, x1, y1, x2, y2;
    
	// grab our preference for extra characters to be included in a word
	wordChars = [[PreferencePanel sharedInstance] wordChars];
	if(wordChars == nil)
		wordChars = @"";		
	// find the beginning of the word
	tmpX = x;
	tmpY = y;
	while(tmpX >= 0)
	{
		aString = [self contentFromX:tmpX Y:tmpY ToX:tmpX Y:tmpY pad: YES];
		if(([aString length] == 0 || 
			[aString rangeOfCharacterFromSet: [NSCharacterSet alphanumericCharacterSet]].length == 0) &&
		   [wordChars rangeOfString: aString].length == 0)
			break;
		tmpX--;
		if(tmpX < 0 && tmpY > 0)
		{
			tmpY--;
			tmpX = [dataSource width] - 1;
		}
	}
	if(tmpX != x)
		tmpX++;
	
	if(tmpX < 0)
		tmpX = 0;
	if(tmpY < 0)
		tmpY = 0;
	if(tmpX >= [dataSource width])
	{
		tmpX = 0;
		tmpY++;
	}
	if(tmpY >= [dataSource numberOfLines])
		tmpY = [dataSource numberOfLines] - 1;	
	if(startx)
		*startx = tmpX;
	if(starty)
		*starty = tmpY;
	x1 = tmpX;
	y1 = tmpY;
	
	
	// find the end of the word
	tmpX = x;
	tmpY = y;
	while(tmpX < [dataSource width])
	{
		aString = [self contentFromX:tmpX Y:tmpY ToX:tmpX Y:tmpY pad: YES];
		if(([aString length] == 0 || 
			[aString rangeOfCharacterFromSet: [NSCharacterSet alphanumericCharacterSet]].length == 0) &&
		   [wordChars rangeOfString: aString].length == 0)
			break;
		tmpX++;
		if(tmpX >= [dataSource width] && tmpY < [dataSource numberOfLines])
		{
			tmpY++;
			tmpX = 0;
		}
	}
	if(tmpX != x)
		tmpX--;
	
	if(tmpX < 0)
	{
		tmpX = [dataSource width] - 1;
		tmpY--;
	}
	if(tmpY < 0)
		tmpY = 0;		
	if(tmpX >= [dataSource width])
		tmpX = [dataSource width] - 1;
	if(tmpY >= [dataSource numberOfLines])
		tmpY = [dataSource numberOfLines] - 1;
	if(endx)
		*endx = tmpX;
	if(endy)
		*endy = tmpY;
	
	x2 = tmpX;
	y2 = tmpY;
    
	return ([self contentFromX:x1 Y:y1 ToX:x2 Y:y2 pad: YES]);
	
}

- (NSString *) _getURLForX: (int) x 
					y: (int) y 
{
	static char *urlSet = ".?/:;%=&_-,+~#@";
	int x1=x, x2=x, y1=y, y2=y;
	int startx=-1, starty=-1, endx, endy;
	int w = [dataSource width];
	int h = [dataSource numberOfLines];
	unichar c;
    
    for (;x1>=0&&y1>=0;) {
        c = [self _getCharacterAtX:x1 Y:y1];
        if (!c || !(isnumber(c) || isalpha(c) || strchr(urlSet, c))) break;
		startx = x1; starty = y1;
		x1--;
		if (x1<0) y1--, x1=w-1;
    }
    if (startx == -1) return nil;

	endx = x; endy = y;
	for (;x2<w&&y2<h;) {
        c = [self _getCharacterAtX:x2 Y:y2];
        if (!c || !(isnumber(c) || isalpha(c) || strchr(urlSet, c))) break;
		endx = x2; endy = y2;
		x2++;
		if (x2>=w) y2++, x2=0;
    }

    NSMutableString *url = [[[NSMutableString alloc] initWithString:[self contentFromX:startx Y:starty ToX:endx Y:endy pad: YES]] autorelease];
	
    
    // Grab the addressbook command
	[url replaceOccurrencesOfString:@"\n" withString:@"" options:NSLiteralSearch range:NSMakeRange(0, [url length])];
    
	return (url);
	
}

- (BOOL) _findMatchingParenthesis: (NSString *) parenthesis withX:(int)X Y:(int)Y
{
	unichar matchingParenthesis, sameParenthesis, c;
	int level = 0, direction;
	int x1, y1;
	int w = [dataSource width];
	int h = [dataSource numberOfLines];
	
	if (!parenthesis || [parenthesis length]<1)  
		return NO;
	
	[parenthesis getCharacters:&sameParenthesis range:NSMakeRange(0,1)];
	switch (sameParenthesis) {
		case '(':
			matchingParenthesis = ')';
			direction = 0;
			break;
		case ')':
			matchingParenthesis = '(';
			direction = 1;
			break;
		case '[':
			matchingParenthesis = ']';
			direction = 0;
			break;
		case ']':
			matchingParenthesis = '[';
			direction = 1;
			break;
		case '{':
			matchingParenthesis = '}';
			direction = 0;
			break;
		case '}':
			matchingParenthesis = '{';
			direction = 1;
			break;
		default:
			return NO;
	}
	
	if (direction) {
		x1 = X -1;
		y1 = Y;
		if (x1<0) y1--, x1=w-1;
		for (;x1>=0&&y1>=0;) {
			c = [self _getCharacterAtX:x1 Y:y1];
			if (c == sameParenthesis) level++;
			else if (c == matchingParenthesis) {
				level--;
				if (level<0) break;
			}
			x1--;
			if (x1<0) y1--, x1=w-1;
		}
		if (level<0) {
			startX = x1;
			startY = y1;
			endX = X;
			endY = Y;

			return YES;
		}
		else 
			return NO;
	}
	else {
		x1 = X +1;
		y1 = Y;
		if (x1>=w) y1++, x1=0;
		
		for (;x1<w&&y1<h;) {
			c = [self _getCharacterAtX:x1 Y:y1];
			if (c == sameParenthesis) level++;
			else if (c == matchingParenthesis) {
				level--;
				if (level<0) break;
			}
			x1++;
			if (x1>=w) y1++, x1=0;
		}
		if (level<0) {
			startX = X;
			startY = Y;
			endX = x1;
			endY = y1;
			
			return YES;
		}
		else 
			return NO;
	}
	
}

- (unsigned int) _checkForSupportedDragTypes:(id <NSDraggingInfo>) sender
{
    NSString *sourceType;
    BOOL iResult;
    
    iResult = NSDragOperationNone;
    
    // We support the FileName drag type for attching files
    sourceType = [[sender draggingPasteboard] availableTypeFromArray: [NSArray arrayWithObjects:
        NSFilenamesPboardType,
        NSStringPboardType,
        nil]];
    
    if (sourceType)
        iResult = NSDragOperationCopy;
    
    return iResult;
}

- (void) _savePanelDidEnd: (NSSavePanel *) theSavePanel
               returnCode: (int) theReturnCode
              contextInfo: (void *) theContextInfo
{
    // If successful, save file under designated name
    if (theReturnCode == NSOKButton)
    {
        if ( ![(NSData *)theContextInfo writeToFile: [theSavePanel filename] atomically: YES] )
            NSBeep();
    }
    // release our hold on the data
    [(NSData *)theContextInfo release];
}
*/

- (BOOL) _isBlankLine: (int) y
{
	NSString *lineContents, *blankLine;
	char blankString[1024];	
	
	
	lineContents = [self contentFromX: 0 Y: y ToX: [dataSource width] - 1 Y: y pad: YES];
	memset(blankString, ' ', 1024);
	blankString[[dataSource width]] = 0;
	blankLine = [NSString stringWithUTF8String: (const char*)blankString];
	
	return ([lineContents isEqualToString: blankLine]);
	
}

/*
- (void) _openURL: (NSString *) aURLString
{
    NSURL *url;
    NSString* trimmedURLString;
	
    trimmedURLString = [aURLString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	// length returns an unsigned value, so couldn't this just be ==? [TRE]
    if([trimmedURLString length] <= 0)
        return;
	    
    // Check for common types of URLs

	NSRange range = [trimmedURLString rangeOfString:@"://"];
	if (range.location == NSNotFound)
		trimmedURLString = [@"http://" stringByAppendingString:trimmedURLString];
	
	url = [NSURL URLWithString:trimmedURLString];

	TreeNode *bm = [[PreferencePanel sharedInstance] handlerBookmarkForURL: [url scheme]];
	
	//NSLog(@"Got the URL:%@\n%@", [url scheme], bm);
	if (bm != nil) 
		[[iTermController sharedInstance] launchBookmark:[bm nodeData] inTerminal:[[iTermController sharedInstance] currentTerminal] withURL:trimmedURLString];
	else 
		[[NSWorkspace sharedWorkspace] openURL:url];
		
}
*/

- (void) _clearCacheForColor:(int)colorIndex
{
	int i;

	for ( i = 0 ; i < cacheSize; i++) {
		if (charImages[i].color == colorIndex) {
			[charImages[i].image release];
			charImages[i].image = nil;
		}
	}
}

- (void) _clearCacheForBGColor:(int)colorIndex
{
	int i;
	
	for ( i = 0 ; i < cacheSize; i++) {
		if (charImages[i].bgColor == colorIndex) {
			[charImages[i].image release];
			charImages[i].image = nil;
		}
	}
}

- (BOOL) _findString: (NSString *) aString forwardDirection: (BOOL) direction ignoringCase: (BOOL) ignoreCase wrapping: (BOOL) wrapping
{
	int x1, y1, x2, y2;
	NSMutableString *searchBody;
	NSRange foundRange;
	int anIndex;
	unsigned searchMask = 0;
	
	if([aString length] <= 0)
	{
// TODO(allen): Beep!
		NSLog(@"Beep");
//		NSBeep();
		return (NO);
	}
	
	// check if we had a previous search result
	if(lastFindX > -1)
	{
		if(direction)
		{
			x1 = lastFindX + 1;
			y1 = lastFindY;
			if(x1 >= [dataSource width])
			{
				if(y1 < [dataSource numberOfLines] - 1)
				{
					// advance search beginning to next line
					x2 = 0;
					y1++;
				}
				else
				{
					if (wrapping) {
						// wrap around to beginning
						x1 = y1 = 0;
					}
					else {
						return NO;
					}
				}
			}
			x2 = [dataSource width] - 1;
			y2 = [dataSource numberOfLines] - 1;
		}
		else
		{
			x1 = y1 = 0;
			x2 = lastFindX - 1;
			y2 = lastFindY;
			if(x2 <= 0)
			{
				if(y2 > 0)
				{
					// stop search at end of previous line
					x2 = [dataSource width] - 1;
					y2--;
				}
				else
				{
					if (wrapping) {
						// wrap around to the end
						x2 = [dataSource width] - 1;
						y2 = [dataSource numberOfLines] - 1;
					}
					else {
						return NO;
					}
				}
			}
		}
	}
	else
	{
		// no previous search results, search from beginning
		x1 = y1 = 0;
		x2 = [dataSource width] - 1;
		y2 = [dataSource numberOfLines] - 1;
	}
	
	// ok, now get the search body
	searchBody = [NSMutableString stringWithString:[self contentFromX: x1 Y: y1 ToX: x2 Y: y2 pad: YES]];
	[searchBody replaceOccurrencesOfString:@"\n" withString:@"" options:NSLiteralSearch range:NSMakeRange(0, [searchBody length])];
	
	if([searchBody length] <= 0)
	{
		NSLog(@"Beep");
//		NSBeep();
		return (NO);
	}
	
	// do the search
	if(ignoreCase)
		searchMask |= NSCaseInsensitiveSearch;
	if(!direction)
		searchMask |= NSBackwardsSearch;	
	foundRange = [searchBody rangeOfString: aString options: searchMask];
	if(foundRange.location != NSNotFound)
	{
		// convert index to coordinates
		// get index of start of search body
		if(y1 > 0)
		{
			anIndex = y1*[dataSource width] + x1;
		}
		else
		{
			anIndex = x1;
		}
				
		// calculate index of start of found range
		anIndex += foundRange.location;
		startX = lastFindX = anIndex % [dataSource width];
		startY = lastFindY = anIndex/[dataSource width];
		
		// end of found range
		anIndex += foundRange.length - 1;
		endX = anIndex % [dataSource width];
		endY = anIndex/[dataSource width];
		
		
		[self _selectFromX:startX Y:startY toX:endX Y:endY];
		[self _scrollToLine:endY];
        [self setForceUpdate:YES];
		[self setNeedsDisplay];
		
		return (YES);
	}
	
	return (NO);
}
/*
- (void) _dragText: (NSString *) aString forEvent: (NSEvent *) theEvent
{
	NSImage *anImage;
	int length;
	NSString *tmpString;
	NSPasteboard *pboard;
	NSArray *pbtypes;
	NSSize imageSize;
    NSPoint dragPoint;
	NSSize dragOffset = NSMakeSize(0.0, 0.0);

	//NSLog(@"%s: %@", __PRETTY_FUNCTION__, aString);

	
	length = [aString length];
	if([aString length] > 15)
		length = 15;
	
	imageSize = NSMakeSize(charWidth*length, lineHeight);
	anImage = [[NSImage alloc] initWithSize: imageSize];
    [anImage lockFocus];
	if([aString length] > 15)
		tmpString = [NSString stringWithFormat: @"%@...", [aString substringWithRange: NSMakeRange(0, 12)]];
	else
		tmpString = [aString substringWithRange: NSMakeRange(0, length)];
		
    [tmpString drawInRect: NSMakeRect(0, 0, charWidth*length, lineHeight) withAttributes: nil];
    [anImage unlockFocus];
    [anImage autorelease];
	
	// get the pasteboard
    pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	
    // Declare the types and put our tabViewItem on the pasteboard
    pbtypes = [NSArray arrayWithObjects: NSStringPboardType, nil];
    [pboard declareTypes: pbtypes owner: self];
    [pboard setString: aString forType: NSStringPboardType];
	
    // tell our app not switch windows (currently not working)
    [NSApp preventWindowOrdering];
	
	// drag from center of the image
    dragPoint = [self convertPoint: [theEvent locationInWindow] fromView: nil];
    dragPoint.x -= imageSize.width/2;
	
    // start the drag
    [self dragImage:anImage at: dragPoint offset:dragOffset
			  event: mouseDownEvent pasteboard:pboard source:self slideBack:YES];
		
}

- (BOOL) _mouseDownOnSelection: (NSEvent *) theEvent
{
	NSPoint locationInWindow, locationInView;
	int row, col;
	unsigned int theBackgroundAttribute;
	BOOL result;
	screen_char_t *theLine;
	
	locationInWindow = [theEvent locationInWindow];
	
	locationInView = [self convertPoint: locationInWindow fromView: nil];
	col = (locationInView.x - MARGIN)/charWidth;
	row = locationInView.y/lineHeight;
	
	theLine = [dataSource getLineAtIndex: row];
	
	theBackgroundAttribute = theLine[col].bg_color;
	
	
	
	if(theBackgroundAttribute & SELECTION_MASK)
		result = YES;
	else
		result = FALSE;
		
	return (result);
	
}
*/

@end
