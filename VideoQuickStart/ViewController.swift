//
//  ViewController.swift
//  VideoQuickStart
//
//  Created by Kevin Whinnery on 12/16/15.
//  Copyright © 2015 Twilio. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
  // MARK: View Controller Members
  
  // Configure access token manually for testing, if desired! Create one manually in the console 
  // at https://www.twilio.com/user/account/video/dev-tools/testing-tools
  var accessToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImN0eSI6InR3aWxpby1mcGE7dj0xIn0.eyJqdGkiOiJTSzgyYjcwZTQzMjNiMDkyYzMwMjcwZDdhNTIwYzM5YWI5LTE0NTc1NTAzOTYiLCJpc3MiOiJTSzgyYjcwZTQzMjNiMDkyYzMwMjcwZDdhNTIwYzM5YWI5Iiwic3ViIjoiQUM0MjhjYWQ0ZjM2ZWFhNDA0N2QyNDQwMTg0ZWIxOGQ3NiIsIm5iZiI6MTQ1NzU1MDM5NiwiZXhwIjoxNDU3NTUzOTk2LCJncmFudHMiOnsiaWRlbnRpdHkiOiJFY2NlbnRyaWNLZW5kcmFLYW5lIiwicnRjIjp7ImNvbmZpZ3VyYXRpb25fcHJvZmlsZV9zaWQiOiJWUzI4ODY5NjBjZDE3NzBiMTIwODdmYjAyOTBlZTgzOTI4In19fQ.gCVAVjvOwSa0Ym_6RNA_dQIY8957X8PaD9pbmigSjqQ"
  
  // Configure remote URL to fetch token from
  var tokenUrl = "http://192.168.0.136:8000/token.php"
  
  // Video SDK components
  var accessManager: TwilioAccessManager?
  var client: TwilioConversationsClient?
  var localMedia: TWCLocalMedia?
  var camera: TWCCameraCapturer?
  var conversation: TWCConversation?
  var incomingInvite: TWCIncomingInvite?
  var outgoingInvite: TWCOutgoingInvite?
	
	// MARK: IP messaging memebers
	var clientChat: TwilioIPMessagingClient? = nil
	var generalChannel: TWMChannel? = nil
	var identity = ""
	var messages: [TWMMessage] = []
	
  // MARK: UI Element Outlets and handles
  var alertController: UIAlertController?
  @IBOutlet weak var remoteMediaView: UIView!
  @IBOutlet weak var localMediaView: UIView!
  @IBOutlet weak var identityLabel: UILabel!
  @IBOutlet weak var hangupButton: UIButton!
  
  // Helper to determine if we're running on simulator or device
  struct Platform {
    static let isSimulator: Bool = {
      var isSim = false
      #if arch(i386) || arch(x86_64)
        isSim = true
      #endif
      return isSim
    }()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    
	videoInitialize()
	chatInitialize()

	
    // Style nav bar elements
    self.navigationController?.navigationBar.barTintColor = UIColor.redColor()
    self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
    self.navigationController?.navigationBar.titleTextAttributes =
      [NSForegroundColorAttributeName : UIColor.whiteColor()]
  }
	
	func videoInitialize()
	{
		// Configure access token either from server or manually
		// If the default wasn't changed, try fetching from server
		if self.accessToken == "TWILIO_ACCESS_TOKEN" {
			// If the token wasn't configured manually, try to fetch it from server
			let config = NSURLSessionConfiguration.defaultSessionConfiguration()
			let session = NSURLSession(configuration: config, delegate: nil, delegateQueue: nil)
			let url = NSURL(string: self.tokenUrl)
			let request  = NSMutableURLRequest(URL: url!)
			request.HTTPMethod = "GET"
			
			// Make HTTP request
			session.dataTaskWithRequest(request, completionHandler: { data, response, error in
				if (data != nil) {
					// Parse result JSON
					let json = JSON(data: data!)
					self.accessToken = json["token"].stringValue
					// Update UI and client on main thread
					dispatch_async(dispatch_get_main_queue()) {
						self.initializeClient()
					}
				} else {
					print("Error fetching token :\(error)")
				}
			}).resume()
		} else {
			// If token was manually set, initialize right away
			self.initializeClient()
		}
		
	}
	
	func chatInitialize()
	{
		// Fetch Access Token form the server and initialize IPM Client - this assumes you are running
		// the PHP starter app on your local machine, as instructed in the quick start guide
		let deviceId = UIDevice.currentDevice().identifierForVendor!.UUIDString
		let urlString = "http://192.168.0.135:8000/token.php?device=\(deviceId)"
		let defaultChannel = "general"
		
		// Get JSON from server
		let config = NSURLSessionConfiguration.defaultSessionConfiguration()
		let session = NSURLSession(configuration: config, delegate: nil, delegateQueue: nil)
		let url = NSURL(string: urlString)
		let request  = NSMutableURLRequest(URL: url!)
		request.HTTPMethod = "GET"
		
		// Make HTTP request
		session.dataTaskWithRequest(request, completionHandler: { data, response, error in
			if (data != nil) {
				// Parse result JSON
				let json = JSON(data: data!)
				let token = json["token"].stringValue
				self.identity = json["identity"].stringValue
				
				// Set up Twilio IPM client and join the general channel
				self.clientChat = TwilioIPMessagingClient.ipMessagingClientWithToken(token, delegate: self)
				
				// Auto-join the general channel
				self.clientChat?.channelsListWithCompletion { result, channels in
					if (result == .Success) {
						if let channel = channels.channelWithUniqueName(defaultChannel) {
							// Join the general channel if it already exists
							self.generalChannel = channel
							self.generalChannel?.joinWithCompletion({ result in
								print("Channel joined with result \(result)")
							})
						} else {
							// Create the general channel (for public use) if it hasn't been created yet
							channels.createChannelWithFriendlyName("General Chat Channel", type: .Public) {
								(channelResult, channel) -> Void in
								if result == .Success {
									self.generalChannel = channel
									self.generalChannel?.joinWithCompletion({ result in
										self.generalChannel?.setUniqueName(defaultChannel, completion: { result in
											print("channel unqiue name set")
										})
									})
								}
							}
						}
					}
				}
				
				// Update UI on main thread
				dispatch_async(dispatch_get_main_queue()) {
					self.navigationItem.prompt = "Logged in as \"\(self.identity)\""
				}
			} else {
				print("Error fetching token :\(error)")
			}
		}).resume()
	}
	
  // Once access token is set, initialize the Conversations SDK and display the identity of the
  // current user
  func initializeClient() {
    // Set up Twilio Conversations client
    self.accessManager = TwilioAccessManager(token:self.accessToken, delegate:self);
    self.client = TwilioConversationsClient(accessManager: self.accessManager!, delegate: self);
    self.client?.listen();
    
    // Setup local media preview
    self.localMedia = TWCLocalMedia(delegate: self)
    self.camera = self.localMedia?.addCameraTrack()
    
    if((self.camera) != nil && Platform.isSimulator != true) {
      self.camera?.videoTrack?.attach(self.localMediaView)
      self.camera?.videoTrack?.delegate = self;
    }
    
    self.identityLabel.text = self.client?.identity
  }

  // MARK: UI Controls
  @IBAction func invite(sender: AnyObject) {
    self.alertController = UIAlertController(title: "Invite User",
      message: "Enter the identity of the user you'd like to call.",
      preferredStyle: UIAlertControllerStyle.Alert)
    
    self.alertController?.addTextFieldWithConfigurationHandler({ textField in
      textField.placeholder = "SomeIdentity"
    })
    
    let action: UIAlertAction = UIAlertAction(title: "invite",
        style: UIAlertActionStyle.Default) { action in
      let invitee = self.alertController?.textFields!.first?.text!
      self.outgoingInvite = self.client?.inviteToConversation(invitee!, localMedia:self.localMedia!)
          { conversation, err in
        if err == nil {
          conversation!.delegate = self
          self.conversation = conversation
        } else {
          print("error creating conversation")
          print(err)
        }
      }
    }
    
    self.alertController?.addAction(action)
    self.presentViewController(self.alertController!, animated: true, completion: nil)
  }
  
  @IBAction func hangup(sender: AnyObject) {
    print("disconnect")
    self.conversation?.disconnect()
  }
}

// MARK: Twilio IP Messaging Delegate
extension ViewController: TwilioIPMessagingClientDelegate {
	// Called whenever a channel we've joined receives a new message
	func ipMessagingClient(client: TwilioIPMessagingClient!, channel: TWMChannel!,
		messageAdded message: TWMMessage!) {
			self.messages.append(message)
			//self.tableView.reloadData()
			dispatch_async(dispatch_get_main_queue()) {
				if self.messages.count > 0 {
					//self.scrollToBottomMessage()
					print("messages")
				}
			}
	}
}

// MARK: TWCLocalMediaDelegate
extension ViewController: TWCLocalMediaDelegate {
  func localMedia(media: TWCLocalMedia, didAddVideoTrack videoTrack: TWCVideoTrack) {
    print("added media track")
  }
}

// MARK: TWCVideoTrackDelegate
extension ViewController: TWCVideoTrackDelegate {
  func videoTrack(track: TWCVideoTrack, dimensionsDidChange dimensions: CMVideoDimensions) {
    print("video dimensions changed")
  }
}

// MARK: TwilioAccessManagerDelegate
extension ViewController: TwilioAccessManagerDelegate {
  func accessManagerTokenExpired(accessManager: TwilioAccessManager!) {
    print("access token has expired")
  }
  
  func accessManager(accessManager: TwilioAccessManager!, error: NSError!) {
    print("Access manager error:")
    print(error)
  }
}

// MARK: TwilioConversationsClientDelegate
extension ViewController: TwilioConversationsClientDelegate {
  func conversationsClient(conversationsClient: TwilioConversationsClient,
      didFailToStartListeningWithError error: NSError) {
    print("failed to start listening:")
    print(error)
  }
  
  // Automatically accept any invitation
  func conversationsClient(conversationsClient: TwilioConversationsClient,
      didReceiveInvite invite: TWCIncomingInvite) {
    print(invite.from)
    invite.acceptWithLocalMedia(self.localMedia!) { conversation, error in
      self.conversation = conversation
      self.conversation!.delegate = self
    }
  }
}

// MARK: TWCConversationDelegate
extension ViewController: TWCConversationDelegate {
  func conversation(conversation: TWCConversation,
      didConnectParticipant participant: TWCParticipant) {
    self.navigationItem.title = participant.identity
    participant.delegate = self
  }
  
  func conversation(conversation: TWCConversation,
      didDisconnectParticipant participant: TWCParticipant) {
    self.navigationItem.title = "participant left"
  }
  
  func conversationEnded(conversation: TWCConversation) {
    self.navigationItem.title = "no call connected"
  }
}

// MARK: TWCParticipantDelegate
extension ViewController: TWCParticipantDelegate {
  func participant(participant: TWCParticipant, addedVideoTrack videoTrack: TWCVideoTrack) {
    videoTrack.attach(self.remoteMediaView)
  }
}

