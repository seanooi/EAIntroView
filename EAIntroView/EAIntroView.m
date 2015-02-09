//
//  EAIntroView.m
//
//  Copyright (c) 2013-2015 Evgeny Aleksandrov. License: MIT.

#import "EAIntroView.h"

@interface EAIntroView()

@property (nonatomic, strong) UIImageView *bgImageView;
@property (nonatomic, strong) UIImageView *pageBgBack;
@property (nonatomic, strong) UIImageView *pageBgFront;

@property(nonatomic, strong) NSMutableArray *footerConstraints;
@property(nonatomic, strong) NSMutableArray *titleViewConstraints;

@end

@interface EAIntroPage()

@property(nonatomic, strong, readwrite) UIView *pageView;

@end


@implementation EAIntroView

@synthesize pageControl = _pageControl;
@synthesize skipButton = _skipButton;

#pragma mark - Init

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self applyDefaultsToSelfDuringInitializationWithFrame:frame pages:nil];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self applyDefaultsToSelfDuringInitializationWithFrame:self.frame pages:nil];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame andPages:(NSArray *)pagesArray {
    self = [super initWithFrame:frame];
    if (self) {
        [self applyDefaultsToSelfDuringInitializationWithFrame:self.frame pages:pagesArray];
    }
    return self;
}

#pragma mark - Private

- (void)applyDefaultsToSelfDuringInitializationWithFrame:(CGRect)frame pages:(NSArray *)pagesArray {
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.swipeToExit = YES;
    self.easeOutCrossDisolves = YES;
    self.hideOffscreenPages = YES;
    self.bgViewContentMode = UIViewContentModeScaleAspectFill;
    self.motionEffectsRelativeValue = 40.f;
    self.backgroundColor = [UIColor blackColor];
    _scrollingEnabled = YES;
    _titleViewY = 20.f;
    _pageControlY = 50.f;
    _skipButtonY = EA_EMPTY_PROPERTY;
    _skipButtonSideMargin = 10.f;
    _skipButtonAlignment = EAViewAlignmentRight;
    
    
    [self buildBackgroundImage];
    
    self.pages = [pagesArray copy];
    
    [self buildFooterView];
}

- (void)applyDefaultsToBackgroundImageView:(UIImageView *)backgroundImageView {
    backgroundImageView.backgroundColor = [UIColor clearColor];
    backgroundImageView.contentMode = self.bgViewContentMode;
    backgroundImageView.autoresizesSubviews = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    backgroundImageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
}

- (void)makePanelVisibleAtIndex:(NSUInteger)panelIndex{
    [UIView animateWithDuration:0.3 animations:^{
        for (int idx = 0; idx < _pages.count; idx++) {
            if (idx == panelIndex) {
                [[self viewForPageIndex:idx] setAlpha:[self alphaForPageIndex:idx]];
            } else {
                if(!self.hideOffscreenPages) {
                    [[self viewForPageIndex:idx] setAlpha:0];
                }
            }
        }
    }];
}

- (EAIntroPage *)pageForIndex:(NSUInteger)idx {
    if(idx >= _pages.count) {
        return nil;
    }
    
    return (EAIntroPage *)_pages[idx];
}

- (CGFloat)alphaForPageIndex:(NSUInteger)idx {
    if(![self pageForIndex:idx]) {
        return 1.f;
    }
    
    return [self pageForIndex:idx].alpha;
}

- (BOOL)showTitleViewForPage:(NSUInteger)idx {
    if(![self pageForIndex:idx]) {
        return NO;
    }
    
    return [self pageForIndex:idx].showTitleView;
}

- (UIView *)viewForPageIndex:(NSUInteger)idx {
    return [self pageForIndex:idx].pageView;
}

- (UIImage *)bgImageForPage:(NSUInteger)idx {
    return [self pageForIndex:idx].bgImage;
}

- (UIColor *)bgColorForPage:(NSUInteger)idx {
    return [self pageForIndex:idx].bgColor;
}

- (void)showPanelAtPageControl {
    [self makePanelVisibleAtIndex:self.currentPageIndex];
    
    [self setCurrentPageIndex:self.pageControl.currentPage animated:YES];
}

- (void)checkIndexForScrollView:(EARestrictedScrollView *)scrollView {
    NSUInteger newPageIndex = (scrollView.contentOffset.x + scrollView.bounds.size.width/2)/self.scrollView.frame.size.width;
    [self notifyDelegateWithPreviousPage:self.currentPageIndex andCurrentPage:newPageIndex];
    _currentPageIndex = newPageIndex;
    
    if (self.currentPageIndex == (_pages.count)) {
        
        //if run here, it means you can't  call _pages[self.currentPageIndex],
        //to be safe, set to the biggest index
        _currentPageIndex = _pages.count - 1;
        
        [self finishIntroductionAndRemoveSelf];
    }
}

- (void)finishIntroductionAndRemoveSelf {
	if ([(id)self.delegate respondsToSelector:@selector(introDidFinish:)]) {
		[self.delegate introDidFinish:self];
	}
    
    //prevent last page flicker on disappearing
    self.alpha = 0;
    
    //Calling removeFromSuperview from scrollViewDidEndDecelerating: method leads to crash on iOS versions < 7.0.
    //removeFromSuperview should be called after a delay
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)0);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self removeFromSuperview];
    });
}

- (void)skipIntroduction {
    [self hideWithFadeOutDuration:0.3];
}

- (void)notifyDelegateWithPreviousPage:(NSUInteger)previousPageIndex andCurrentPage:(NSUInteger)currentPageIndex {
    if(currentPageIndex!=_currentPageIndex && currentPageIndex < _pages.count) {
        EAIntroPage* previousPage = _pages[previousPageIndex];
        EAIntroPage* currentPage = _pages[currentPageIndex];
        if(previousPage.onPageDidDisappear) previousPage.onPageDidDisappear();
        if(currentPage.onPageDidAppear) currentPage.onPageDidAppear();
        
        if ([(id)self.delegate respondsToSelector:@selector(intro:pageAppeared:withIndex:)]) {
            [self.delegate intro:self pageAppeared:_pages[currentPageIndex] withIndex:currentPageIndex];
        }
    }
}

#pragma mark - Properties

- (EARestrictedScrollView *)scrollView {
    if (!_scrollView) {
        _scrollView = [[EARestrictedScrollView alloc] initWithFrame:self.bounds];
        _scrollView.accessibilityIdentifier = @"intro_scroll";
        _scrollView.pagingEnabled = YES;
        _scrollView.alwaysBounceHorizontal = YES;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.delegate = self;
        _scrollView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    }
    return _scrollView;
}

- (NSUInteger)visiblePageIndex {
    return (NSUInteger) ((self.scrollView.contentOffset.x + self.scrollView.bounds.size.width/2) / self.scrollView.frame.size.width);
}

- (UIImageView *)bgImageView {
    if (!_bgImageView) {
        _bgImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        _bgImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self applyDefaultsToBackgroundImageView:_bgImageView];
    }
    return _bgImageView;
}

- (UIImageView *)pageBgBack {
    if (!_pageBgBack) {
        _pageBgBack = [[UIImageView alloc] initWithFrame:self.bounds];
        [self applyDefaultsToBackgroundImageView:_pageBgBack];
        _pageBgBack.alpha = 0;
    }
    return _pageBgBack;
}

- (UIImageView *)pageBgFront {
    if (!_pageBgFront) {
        _pageBgFront = [[UIImageView alloc] initWithFrame:self.bounds];
        [self applyDefaultsToBackgroundImageView:_pageBgFront];
        _pageBgFront.alpha = 0;
    }
    return _pageBgFront;
}

- (UIPageControl *)pageControl {
    if (!_pageControl) {
        _pageControl = [[UIPageControl alloc] init];
        [self applyDefaultsToPageControl];
    }
    return _pageControl;
}

- (void)applyDefaultsToPageControl {
    _pageControl.defersCurrentPageDisplay = YES;
    _pageControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _pageControl.numberOfPages = _pages.count;
    if ([_pageControl respondsToSelector:@selector(setTranslatesAutoresizingMaskIntoConstraints:)]) {
        _pageControl.translatesAutoresizingMaskIntoConstraints = NO;
    }
    [_pageControl addTarget:self action:@selector(showPanelAtPageControl) forControlEvents:UIControlEventValueChanged];
}

- (UIButton *)skipButton {
    if (!_skipButton) {
        _skipButton = [[UIButton alloc] init];
        [_skipButton setTitle:NSLocalizedString(@"Skip", nil) forState:UIControlStateNormal];
        [self applyDefaultsToSkipButton];
    }
    return _skipButton;
}

- (void)applyDefaultsToSkipButton {
    _skipButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_skipButton addTarget:self action:@selector(skipIntroduction) forControlEvents:UIControlEventTouchUpInside];
    if ([_skipButton respondsToSelector:@selector(setTranslatesAutoresizingMaskIntoConstraints:)]) {
        _skipButton.translatesAutoresizingMaskIntoConstraints = NO;
    }
}

- (NSMutableArray *)footerConstraints {
    if (!_footerConstraints) {
        _footerConstraints = [NSMutableArray array];
    }
    return _footerConstraints;
}

- (NSMutableArray *)titleViewConstraints {
    if (!_titleViewConstraints) {
        _titleViewConstraints = [NSMutableArray array];
    }
    return _titleViewConstraints;
}

#pragma mark - UI building

- (void)buildBackgroundImage {
    [self addSubview:self.bgImageView];
    [self addSubview:self.pageBgBack];
    [self addSubview:self.pageBgFront];
    
    if (self.useMotionEffects) {
        [self addMotionEffectsOnBg];
    }
}

- (void)buildScrollView {
    CGFloat contentXIndex = 0;
    for (NSUInteger idx = 0; idx < _pages.count; idx++) {
        EAIntroPage *page = _pages[idx];
        page.pageView = [self viewForPage:page atXIndex:contentXIndex];
        contentXIndex += self.scrollView.frame.size.width;
        [self.scrollView addSubview:page.pageView];
        if(page.onPageDidLoad) page.onPageDidLoad();
    }
    
    [self makePanelVisibleAtIndex:0];
    
    if (self.swipeToExit) {
        [self appendCloseViewAtXIndex:&contentXIndex];
    }
    
    [self insertSubview:self.scrollView aboveSubview:self.pageBgFront];
    self.scrollView.contentSize = CGSizeMake(contentXIndex, self.scrollView.frame.size.height);
    
    self.pageBgBack.alpha = 0;
    self.pageBgBack.image = [self bgImageForPage:1];
    self.pageBgBack.backgroundColor = [self bgColorForPage:1];
    self.pageBgFront.alpha = [self alphaForPageIndex:0];
    self.pageBgFront.image = [self bgImageForPage:0];
    self.pageBgFront.backgroundColor = [self bgColorForPage:0];
}

- (UIView *)viewForPage:(EAIntroPage *)page atXIndex:(CGFloat)xIndex {
    UIView *pageView = [[UIView alloc] initWithFrame:CGRectMake(xIndex, 0, self.scrollView.frame.size.width, self.scrollView.frame.size.height)];
    
    if(page.customView) {
        page.customView.frame = pageView.bounds;
        [pageView addSubview:page.customView];
        return pageView;
    }
    
    UIButton *tapToNextButton = [UIButton buttonWithType:UIButtonTypeCustom];
    tapToNextButton.frame = pageView.bounds;
    [tapToNextButton addTarget:self action:@selector(goToNext:) forControlEvents:UIControlEventTouchUpInside];
    [pageView addSubview:tapToNextButton];
    
    if(page.titleIconView) {
        UIView *titleImageView = page.titleIconView;
        CGRect rect1 = titleImageView.frame;
        rect1.origin.x = (self.scrollView.frame.size.width - rect1.size.width)/2;
        rect1.origin.y = page.titleIconPositionY;
        titleImageView.frame = rect1;
        titleImageView.tag = kTitleImageViewTag;
        
        [pageView addSubview:titleImageView];
    }
    
    if(page.title.length) {
        CGFloat titleHeight;
        
        if ([page.title respondsToSelector:@selector(boundingRectWithSize:options:attributes:context:)]) {
            NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:page.title attributes:@{ NSFontAttributeName: page.titleFont }];
            CGRect rect = [attributedText boundingRectWithSize:(CGSize){self.scrollView.frame.size.width - 20, CGFLOAT_MAX} options:NSStringDrawingUsesLineFragmentOrigin context:nil];
            titleHeight = ceilf(rect.size.height);
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            titleHeight = [page.title sizeWithFont:page.titleFont constrainedToSize:CGSizeMake(self.scrollView.frame.size.width - 20, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping].height;
#pragma clang diagnostic pop
        }
        
        CGRect titleLabelFrame = CGRectMake(10, self.bounds.size.height - page.titlePositionY, self.scrollView.frame.size.width - 20, titleHeight);
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:titleLabelFrame];
        titleLabel.text = page.title;
        titleLabel.font = page.titleFont;
        titleLabel.textColor = page.titleColor;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        titleLabel.numberOfLines = 0;
        titleLabel.tag = kTitleLabelTag;
        
        [pageView addSubview:titleLabel];
    }
    
    if([page.desc length]) {
        CGRect descLabelFrame;
        
        if(page.descWidth != 0) {
            descLabelFrame = CGRectMake((self.bounds.size.width - page.descWidth)/2, self.bounds.size.height - page.descPositionY, page.descWidth, 500);
        } else {
            descLabelFrame = CGRectMake(0, self.bounds.size.height - page.descPositionY, self.scrollView.frame.size.width, 500);
        }
        
        UITextView *descLabel = [[UITextView alloc] initWithFrame:descLabelFrame];
        descLabel.text = page.desc;
        descLabel.scrollEnabled = NO;
        descLabel.font = page.descFont;
        descLabel.textColor = page.descColor;
        descLabel.backgroundColor = [UIColor clearColor];
        descLabel.textAlignment = NSTextAlignmentCenter;
        descLabel.userInteractionEnabled = NO;
        descLabel.tag = kDescLabelTag;
        
        [pageView addSubview:descLabel];
    }
    
    if(page.subviews) {
        for (UIView *subV in page.subviews) {
            [pageView addSubview:subV];
        }
    }
    
    pageView.accessibilityLabel = [NSString stringWithFormat:@"intro_page_%lu",(unsigned long)[self.pages indexOfObject:page]];
    
    if(page.alpha < 1.f || !page.bgImage) {
        self.backgroundColor = [UIColor clearColor];
    }
    
    pageView.alpha = page.alpha;
    
    return pageView;
}

- (void)appendCloseViewAtXIndex:(CGFloat*)xIndex {
    UIView *closeView = [[UIView alloc] initWithFrame:CGRectMake(*xIndex, 0, self.bounds.size.width, self.bounds.size.height)];
    closeView.tag = 124;
    [self.scrollView addSubview:closeView];
    
    *xIndex += self.scrollView.frame.size.width;
}

- (void)removeCloseViewAtXIndex:(CGFloat*)xIndex {
    UIView *closeView = [self.scrollView viewWithTag:124];
    if(closeView) {
        [closeView removeFromSuperview];
    }
    
    *xIndex -= self.scrollView.frame.size.width;
}

- (void)buildTitleView {
    if (!self.titleView.superview) {
        [self addSubview:self.titleView];
    }
    
    if ([self respondsToSelector:@selector(addConstraint:)]) {
        if (self.titleViewConstraints.count) {
            [self removeConstraints:self.titleViewConstraints];
            [self.titleViewConstraints removeAllObjects];
        }
        
        NSDictionary *views = @{@"titleView" : self.titleView};
        NSDictionary *metrics = @{@"titleViewTopPadding" : @(self.titleViewY), @"titleViewHeight" : @(self.titleView.frame.size.height), @"titleViewWidth" : @(self.titleView.frame.size.width)};
        
        [self.titleViewConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-titleViewTopPadding-[titleView(titleViewHeight)]" options:NSLayoutFormatAlignAllLeft metrics:metrics views:views]];
        [self.titleViewConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[titleView(titleViewWidth)]" options:NSLayoutFormatAlignAllTop metrics:metrics views:views]];
        [self.titleViewConstraints addObject:[NSLayoutConstraint constraintWithItem:self.titleView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0]];
        
        self.titleView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addConstraints:self.titleViewConstraints];
        
        [self.titleView setNeedsUpdateConstraints];
    }
}

- (void)buildFooterView {
    if (!self.pageControl.superview) {
        [self insertSubview:self.pageControl aboveSubview:self.scrollView];
    }
    
    if (!self.skipButton.superview) {
        [self insertSubview:self.skipButton aboveSubview:self.scrollView];
    }
    
    [self.pageControl.superview bringSubviewToFront:self.pageControl];
    [self.skipButton.superview bringSubviewToFront:self.skipButton];
    
    if ([self respondsToSelector:@selector(addConstraint:)]) {
        if (self.footerConstraints.count) {
            [self removeConstraints:self.footerConstraints];
            [self.footerConstraints removeAllObjects];
        }
        
        NSDictionary *views = @{@"pageControl" : self.pageControl, @"skipButton" : self.skipButton};
        NSDictionary *metrics = @{@"pageControlBottomPadding" : @(self.pageControlY - self.pageControl.frame.size.height), @"pageControlHeight" : @(self.pageControl.frame.size.height), @"skipButtonBottomPadding" : @(self.skipButtonY - self.skipButton.frame.size.height), @"skipButtonSideMargin" : @(self.skipButtonSideMargin), @"frameWidth" : @(self.bounds.size.width), @"skipButtonWidth" : @(self.skipButton.frame.size.width)};
        
        [self.footerConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[pageControl(frameWidth)]-0-|" options:NSLayoutFormatAlignAllCenterX metrics:metrics views:views]];
        [self.footerConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[pageControl(pageControlHeight)]-pageControlBottomPadding-|" options:NSLayoutFormatAlignAllBottom metrics:metrics views:views]];
        
        if (self.skipButton && !self.skipButton.hidden) {
            if(self.skipButtonAlignment == EAViewAlignmentCenter) {
                [self.footerConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[skipButton(skipButtonWidth)]" options:NSLayoutFormatAlignAllTop metrics:metrics views:views]];
                [self.footerConstraints addObject:[NSLayoutConstraint constraintWithItem:self.skipButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0]];
            } else if(self.skipButtonAlignment == EAViewAlignmentLeft) {
                [self.footerConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-skipButtonSideMargin-[skipButton]" options:NSLayoutFormatAlignAllLeft metrics:metrics views:views]];
            } else if(self.skipButtonAlignment == EAViewAlignmentRight) {
                [self.footerConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[skipButton]-skipButtonSideMargin-|" options:NSLayoutFormatAlignAllRight metrics:metrics views:views]];
            }
            
            if(self.skipButtonY == EA_EMPTY_PROPERTY) {
                [self.footerConstraints addObject:[NSLayoutConstraint constraintWithItem:self.pageControl attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.skipButton attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0.0]];
            } else {
                [self.footerConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[skipButton]-skipButtonBottomPadding-|" options:NSLayoutFormatAlignAllCenterX metrics:metrics views:views]];
            }
        }
        
        [self addConstraints:self.footerConstraints];
        
        [self.pageControl setNeedsUpdateConstraints];
        [self.skipButton setNeedsUpdateConstraints];
    }
}

#pragma mark - UIScrollView Delegate
- (void)scrollViewWillBeginDragging:(EARestrictedScrollView *)scrollView{
    if ([self.delegate respondsToSelector:@selector(intro:pageStartScrolling:withIndex:)] && self.currentPageIndex < [self.pages count]) {
        [self.delegate intro:self pageStartScrolling:_pages[self.currentPageIndex] withIndex:self.currentPageIndex];
    }
}

- (void)scrollViewDidEndDecelerating:(EARestrictedScrollView *)scrollView {
    [self checkIndexForScrollView:scrollView];
    if ([self.delegate respondsToSelector:@selector(intro:pageEndScrolling:withIndex:)] && self.currentPageIndex < [self.pages count]) {
        [self.delegate intro:self pageEndScrolling:_pages[self.currentPageIndex] withIndex:self.currentPageIndex];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(EARestrictedScrollView *)scrollView {
    [self checkIndexForScrollView:scrollView];
}

- (void)scrollViewDidScroll:(EARestrictedScrollView *)scrollView {
    if(!self.scrollingEnabled) {
        return;
    }
    
    CGFloat offset = scrollView.contentOffset.x / self.scrollView.frame.size.width;
    NSUInteger page = (NSUInteger)(offset);
    
    if (page == (_pages.count - 1) && self.swipeToExit) {
        self.alpha = ((self.scrollView.frame.size.width*_pages.count)-self.scrollView.contentOffset.x)/self.scrollView.frame.size.width;
        if ([(id)self.delegate respondsToSelector:@selector(introWillFadeOut:)] && self.currentPageIndex < [self.pages count]) {
            [self.delegate introWillFadeOut:self.alpha];
        }
    } else {
        if([self pageForIndex:page]) {
            self.alpha = 1.f;
        }
        
        [self crossDissolveForOffset:offset];
    }
    
    if (self.visiblePageIndex < _pages.count) {
        self.pageControl.currentPage = self.visiblePageIndex;
        
        [self makePanelVisibleAtIndex:self.visiblePageIndex];
    }
}

CGFloat easeOutValue(CGFloat value) {
    CGFloat inverse = value - 1.f;
    return (CGFloat) (1.f + inverse * inverse * inverse);
}

- (void)crossDissolveForOffset:(CGFloat)offset {
    NSUInteger page = (NSUInteger)(offset);
    CGFloat alphaValue = offset - page;
    
    if (alphaValue < 0 && self.visiblePageIndex == 0){
        self.pageBgBack.image = nil;
        return;
    }
    
    self.pageBgFront.alpha = [self alphaForPageIndex:page];
    self.pageBgFront.image = [self bgImageForPage:page];
    self.pageBgFront.backgroundColor = [self bgColorForPage:page];
    self.pageBgBack.alpha = 0;
    self.pageBgBack.image = [self bgImageForPage:page+1];
    self.pageBgBack.backgroundColor = [self bgColorForPage:page+1];
    
    CGFloat backLayerAlpha = alphaValue;
    CGFloat frontLayerAlpha = (1 - alphaValue);
    
    if (self.easeOutCrossDisolves) {
        backLayerAlpha = easeOutValue(backLayerAlpha);
        frontLayerAlpha = easeOutValue(frontLayerAlpha);
    }
    
    self.pageBgBack.alpha = MIN(backLayerAlpha,[self alphaForPageIndex:page+1]);
    self.pageBgFront.alpha = MIN(frontLayerAlpha,[self alphaForPageIndex:page]);
    
    if(self.titleView) {
        if([self showTitleViewForPage:page] && [self showTitleViewForPage:page+1]) {
            [self.titleView setAlpha:1.0];
        } else if(![self showTitleViewForPage:page] && ![self showTitleViewForPage:page+1]) {
            [self.titleView setAlpha:0.0];
        } else if([self showTitleViewForPage:page]) {
            [self.titleView setAlpha:(1 - alphaValue)];
        } else {
            [self.titleView setAlpha:alphaValue];
        }
    }
    
    if(self.skipButton && self.showSkipButtonOnlyOnLastPage) {
        if(page < (long)[self.pages count] - 2) {
            [self.skipButton setAlpha:0.0];
        } else if(page == [self.pages count] - 1) {
            [self.skipButton setAlpha:(1 - alphaValue)];
        } else {
            [self.skipButton setAlpha:alphaValue];
        }
    }
}

#pragma mark - Custom setters

- (void)setScrollingEnabled:(BOOL)scrollingEnabled {
    if(!scrollingEnabled) {
        self.scrollView.restrictionArea = CGRectMake(self.visiblePageIndex * self.bounds.size.width, 0, self.scrollView.bounds.size.width, self.scrollView.bounds.size.height);
    } else {
        self.scrollView.restrictionArea = CGRectZero;
    }
    
    _scrollingEnabled = scrollingEnabled;
}

- (void)setPages:(NSArray *)pages {
    _pages = [pages copy];
    [self.scrollView removeFromSuperview];
    self.scrollView = nil;
    [self buildScrollView];
    self.pageControl.numberOfPages = _pages.count;
}

- (void)setBgImage:(UIImage *)bgImage {
    _bgImage = bgImage;
    self.bgImageView.image = _bgImage;
    
    [self setNeedsDisplay];
}

- (void)setBgViewContentMode:(UIViewContentMode)bgViewContentMode {
    _bgViewContentMode = bgViewContentMode;
    self.bgImageView.contentMode = bgViewContentMode;
    self.pageBgBack.contentMode = bgViewContentMode;
    self.pageBgFront.contentMode = bgViewContentMode;
    
    [self setNeedsDisplay];
}

- (void)setSwipeToExit:(BOOL)swipeToExit {
    if (swipeToExit != _swipeToExit) {
        CGFloat contentXIndex = self.scrollView.contentSize.width;
        if(swipeToExit) {
            [self appendCloseViewAtXIndex:&contentXIndex];
        } else {
            [self removeCloseViewAtXIndex:&contentXIndex];
        }
        self.scrollView.contentSize = CGSizeMake(contentXIndex, self.scrollView.frame.size.height);
    }
    _swipeToExit = swipeToExit;
}

- (void)setTitleView:(UIView *)titleView {
    [_titleView removeFromSuperview];
    _titleView = titleView;
    
    if ([_titleView respondsToSelector:@selector(setTranslatesAutoresizingMaskIntoConstraints:)]) {
        _titleView.translatesAutoresizingMaskIntoConstraints = NO;
    }
    
    CGFloat offset = self.scrollView.contentOffset.x / self.scrollView.frame.size.width;
    [self crossDissolveForOffset:offset];
    
    [self buildTitleView];
    
    [self setNeedsDisplay];
}

- (void)setTitleViewY:(CGFloat)titleViewY {
    _titleViewY = titleViewY;
    
    [self buildTitleView];
    
    [self setNeedsDisplay];
}

- (void)setPageControl:(UIPageControl *)pageControl {
    [_pageControl removeFromSuperview];
    _pageControl = pageControl;
    [self applyDefaultsToPageControl];
    
    [self buildFooterView];
    
    [self setNeedsDisplay];
}

- (void)setPageControlY:(CGFloat)pageControlY {
    _pageControlY = pageControlY;
    
    [self buildFooterView];
    
    [self setNeedsDisplay];
}

- (void)setSkipButton:(UIButton *)skipButton {
    [_skipButton removeFromSuperview];
    _skipButton = skipButton;
    [self applyDefaultsToSkipButton];
    
    [self buildFooterView];
    
    [self setNeedsDisplay];
}

- (void)setSkipButtonY:(CGFloat)skipButtonY {
    _skipButtonY = skipButtonY;
    
    [self buildFooterView];
    
    [self setNeedsDisplay];
}

- (void)setSkipButtonSideMargin:(CGFloat)skipButtonSideMargin {
    _skipButtonSideMargin = skipButtonSideMargin;
    
    [self buildFooterView];
    
    [self setNeedsDisplay];
}

- (void)setSkipButtonAlignment:(EAViewAlignment)skipButtonAlignment {
    _skipButtonAlignment = skipButtonAlignment;
    
    [self buildFooterView];
    
    [self setNeedsDisplay];
}

- (void)setShowSkipButtonOnlyOnLastPage:(BOOL)showSkipButtonOnlyOnLastPage {
    _showSkipButtonOnlyOnLastPage = showSkipButtonOnlyOnLastPage;
    
    CGFloat offset = self.scrollView.contentOffset.x / self.scrollView.frame.size.width;
    [self crossDissolveForOffset:offset];
}

- (void)setUseMotionEffects:(BOOL)useMotionEffects {
    if(_useMotionEffects == useMotionEffects) {
        return;
    }
    _useMotionEffects = useMotionEffects;
    
    if(useMotionEffects) {
        [self addMotionEffectsOnBg];
    } else {
        [self removeMotionEffectsOnBg];
    }
}

- (void)setMotionEffectsRelativeValue:(CGFloat)motionEffectsRelativeValue {
    _motionEffectsRelativeValue = motionEffectsRelativeValue;
    if(self.useMotionEffects) {
        [self addMotionEffectsOnBg];
    }
}

#pragma mark - Motion effects actions

- (void)addMotionEffectsOnBg {
    if(![self respondsToSelector:@selector(setMotionEffects:)]) {
        return;
    }
    
    CGRect parallaxFrame = CGRectMake(-self.motionEffectsRelativeValue, -self.motionEffectsRelativeValue, self.bounds.size.width + (self.motionEffectsRelativeValue * 2), self.bounds.size.height + (self.motionEffectsRelativeValue * 2));
    [self.pageBgFront setFrame:parallaxFrame];
    [self.pageBgBack setFrame:parallaxFrame];
    [self.bgImageView setFrame:parallaxFrame];
    
    // Set vertical effect
    UIInterpolatingMotionEffect *verticalMotionEffect =
    [[UIInterpolatingMotionEffect alloc]
     initWithKeyPath:@"center.y"
     type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
    verticalMotionEffect.minimumRelativeValue = @(self.motionEffectsRelativeValue);
    verticalMotionEffect.maximumRelativeValue = @(-self.motionEffectsRelativeValue);
    
    // Set horizontal effect
    UIInterpolatingMotionEffect *horizontalMotionEffect =
    [[UIInterpolatingMotionEffect alloc]
     initWithKeyPath:@"center.x"
     type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
    horizontalMotionEffect.minimumRelativeValue = @(self.motionEffectsRelativeValue);
    horizontalMotionEffect.maximumRelativeValue = @(-self.motionEffectsRelativeValue);
    
    // Create group to combine both
    UIMotionEffectGroup *group = [UIMotionEffectGroup new];
    group.motionEffects = @[horizontalMotionEffect, verticalMotionEffect];
    
    // Add both effects to all background image views
    [UIView animateWithDuration:0.5f animations:^{
        [self.pageBgFront setMotionEffects:@[group]];
        [self.pageBgBack setMotionEffects:@[group]];
        [self.bgImageView setMotionEffects:@[group]];
    }];
}

- (void)removeMotionEffectsOnBg {
    if(![self respondsToSelector:@selector(removeMotionEffect:)]) {
        return;
    }
    
    [UIView animateWithDuration:0.5f animations:^{
        [self.pageBgFront removeMotionEffect:self.pageBgFront.motionEffects[0]];
        [self.pageBgBack removeMotionEffect:self.pageBgBack.motionEffects[0]];
        [self.bgImageView removeMotionEffect:self.bgImageView.motionEffects[0]];
    }];
}

#pragma mark - Actions

- (void)showInView:(UIView *)view animateDuration:(CGFloat)duration {
    [self showInView:view animateDuration:duration withInitialPageIndex:0];
}

- (void)showInView:(UIView *)view animateDuration:(CGFloat)duration withInitialPageIndex:(NSUInteger)initialPageIndex {
    if(![self pageForIndex:initialPageIndex]) {
        NSLog(@"Wrong initialPageIndex received: %ld",(long)initialPageIndex);
        return;
    }
    
    self.currentPageIndex = initialPageIndex;
    self.alpha = 0;

    [view addSubview:self];
   
    [UIView animateWithDuration:duration animations:^{
        self.alpha = 1;
    } completion:^(BOOL finished) {
        EAIntroPage *currentPage = _pages[self.currentPageIndex];
        if(currentPage.onPageDidAppear) currentPage.onPageDidAppear();
        
        if ([(id)self.delegate respondsToSelector:@selector(intro:pageAppeared:withIndex:)]) {
            [self.delegate intro:self pageAppeared:_pages[self.currentPageIndex] withIndex:self.currentPageIndex];
        }
    }];
}

- (void)hideWithFadeOutDuration:(CGFloat)duration {
    [UIView animateWithDuration:duration animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished){
		[self finishIntroductionAndRemoveSelf];
	}];
}

- (void)setCurrentPageIndex:(NSUInteger)currentPageIndex {
    [self setCurrentPageIndex:currentPageIndex animated:NO];
}

- (void)setCurrentPageIndex:(NSUInteger)currentPageIndex animated:(BOOL)animated {
    if(![self pageForIndex:currentPageIndex]) {
        NSLog(@"Wrong currentPageIndex received: %ld",(long)currentPageIndex);
        return;
    }
    
    CGFloat offset = currentPageIndex * self.scrollView.frame.size.width;
    CGRect pageRect = { .origin.x = offset, .origin.y = 0.0, .size.width = self.scrollView.frame.size.width, .size.height = self.scrollView.frame.size.height };
    [self.scrollView scrollRectToVisible:pageRect animated:animated];
}

- (IBAction)goToNext:(id)sender {
    if(!self.tapToNext) {
        return;
    }
    if(self.currentPageIndex + 1 >= [self.pages count]) {
        [self hideWithFadeOutDuration:0.3];
    } else {
        [self setCurrentPageIndex:self.currentPageIndex + 1 animated:YES];
    }
}

- (void)limitScrollingToPage:(NSUInteger)lastPageIndex {
    if (lastPageIndex >= [self.pages count]) {
        self.scrollingEnabled = YES;
        return;
    }
    
    _scrollingEnabled = YES;
    self.scrollView.restrictionArea = CGRectMake(0, 0, (lastPageIndex + 1) * self.scrollView.bounds.size.width, self.scrollView.bounds.size.height);
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // if we haven't autolayout, use layoutsubviews
    _titleView.frame = CGRectMake((self.bounds.size.width-_titleView.frame.size.width)/2, self.titleViewY, _titleView.frame.size.width, _titleView.frame.size.height);
    _pageControl.frame = CGRectMake(0, self.bounds.size.height - self.pageControlY, self.bounds.size.width, 20);
    
    CGFloat skipButtonY = (self.skipButtonY == EA_EMPTY_PROPERTY) ? (self.pageControl.frame.origin.y + (self.pageControl.frame.size.height - 30)/2) : self.bounds.size.height - self.skipButtonY;
    if(self.skipButtonAlignment == EAViewAlignmentCenter) {
        _skipButton.frame = CGRectMake((self.bounds.size.width - self.skipButton.frame.size.width)/2, skipButtonY, self.skipButton.frame.size.width, self.skipButton.frame.size.height);
    } else if(self.skipButtonAlignment == EAViewAlignmentLeft) {
        _skipButton.frame = CGRectMake(self.skipButton.frame.size.width + self.skipButtonSideMargin, skipButtonY, self.skipButton.frame.size.width, self.skipButton.frame.size.height);
    } else if(self.skipButtonAlignment == EAViewAlignmentRight) {
        _skipButton.frame = CGRectMake(self.bounds.size.width - self.skipButton.frame.size.width - self.skipButtonSideMargin, skipButtonY, self.skipButton.frame.size.width, self.skipButton.frame.size.height);
    }
}

@end
