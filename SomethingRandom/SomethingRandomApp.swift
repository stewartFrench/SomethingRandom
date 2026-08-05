//
//  SomethingRandomApp.swift
//  SomethingRandom
//
//  Created by Stewart French on 7/24/26.
//
//  Developed with significant assistance from Claude Sonnet 4.5 by
//  Anthropic.
// 

import SwiftUI
import AVFoundation


// -----------------------------------------

@main
struct SomethingRandomApp: App
{
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    
    
    var body: some Scene
    {
        WindowGroup
        {
            ContentView()
                .onAppear
                {
                    AppDelegate.orientationLock = .portrait
                } // onAppear
        } // WindowGroup
    } // body
} // struct SomethingRandomApp


// -----------------------------------------
// App delegate to handle background tasks

class AppDelegate: NSObject, UIApplicationDelegate
{
    static var orientationLock = UIInterfaceOrientationMask.portrait
    
    
    
    // -------------

    func application(_ application                : UIApplication,
                     didFinishLaunchingWithOptions launchOptions : 
                                          [UIApplication.LaunchOptionsKey : Any]? = nil) 
         -> Bool
    {
        // Configure audio session for background playback
        
        do
        {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Use .playback category to ensure audio plays even in silent mode
            
            try audioSession.setCategory(.playback,
                                    mode    : .voicePrompt,
                                    options : [.mixWithOthers])

            try audioSession.setActive(true)
        } // do
        catch
        {
            // print("Failed to configure audio session: \(error)")
        } // catch
        
        return true
    } // application
    
    
    
    // -------------

    func application(_ application                             : UIApplication,
                     supportedInterfaceOrientationsFor window  : UIWindow?) 
         -> UIInterfaceOrientationMask
    {
        return AppDelegate.orientationLock
    } // application supportedInterfaceOrientationsFor
} // class AppDelegate
