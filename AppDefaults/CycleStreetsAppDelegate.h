/*

Copyright (C) 2010  CycleStreets Ltd

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

*/

//  CycleStreetsAppDelegate.h
//  CycleStreets
//
//  Created by Alan Paxton on 02/03/2010.
//

#import <UIKit/UIKit.h>
@class FavouritesViewController;
#import "StartupManager.h"
#import "ExpandedUILabel.h"

#define ISDEVELOPMENT 1

@interface CycleStreetsAppDelegate : NSObject <UIApplicationDelegate,StartupManagerDelegate,UITabBarControllerDelegate> {
	
    UIWindow *window;
	
	UIImageView			*splashView;
	
	UITabBarController *tabBarController;
	
	StartupManager				*startupmanager;
	ExpandedUILabel					*debugLabel;
	
	//TO BE DEPRECATED, these shouldnt be hard wired via the delegate, use notifications or kvo
	FavouritesViewController		*favourites;
	
}

@property (nonatomic, retain)	UIWindow		*window;
@property (nonatomic, retain)	UIImageView		*splashView;
@property (nonatomic, retain)	UITabBarController		*tabBarController;
@property (nonatomic, retain)	StartupManager		*startupmanager;
@property (nonatomic, retain)	ExpandedUILabel		*debugLabel;
@property (nonatomic, retain)	FavouritesViewController		*favourites;


- (UINavigationController *)setupNavigationTab:(UIViewController *)controller withTitle:(NSString *)title imageNamed:(NSString *)imageName tag:(int)tag;
-(void)showTabBarViewControllerByName:(NSString*)viewname;

@end

