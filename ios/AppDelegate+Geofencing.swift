//
//  AppDelegate+Geofencing.swift
//  geofencingapp
//
//  Created by thiago.lioy on 20/03/20.
//  Copyright © 2020 Facebook. All rights reserved.
//

import Foundation
import CoreLocation
import UserNotifications

class LocationService {
  static let shared = LocationService()
  let locationManager = CLLocationManager()
  var geotifications: [Geotification] = []
  
  private init() {}
  
}

extension AppDelegate {
  
  @objc public func startGeolocationServices(){
    print("Initializing GeolocationServices")
    LocationService.shared.locationManager.delegate = self
    DispatchQueue.main.async {
      LocationService.shared.locationManager.requestAlwaysAuthorization()
      let options: UNAuthorizationOptions = [.badge, .sound, .alert]
      UNUserNotificationCenter.current()
        .requestAuthorization(options: options) { success, error in
          if let error = error {
            print("Error: \(error)")
          } else {
            self.loadAllGeotifications()
          }
      }
    }
    
  }
  
  func applicationDidBecomeActive(_ application: UIApplication) {
    application.applicationIconBadgeNumber = 0
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
  }
  
  
  
  func handleEvent(for region: CLRegion!) {
    // Show an alert if application is active
    if UIApplication.shared.applicationState == .active {
      guard let message = note(from: region.identifier) else { return }
      showAlert(withTitle: nil, message: message)
    } else {
      // Otherwise present a local notification
      guard let body = note(from: region.identifier) else { return }
      let notificationContent = UNMutableNotificationContent()
      notificationContent.body = body
      notificationContent.sound = UNNotificationSound.default
      notificationContent.badge = UIApplication.shared.applicationIconBadgeNumber + 1 as NSNumber
      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
      let request = UNNotificationRequest(identifier: "location_change",
                                          content: notificationContent,
                                          trigger: trigger)
      UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
          print("Error: \(error)")
        }
      }
    }
  }
  
  func note(from identifier: String) -> String? {
    guard let matched = LocationService.shared.geotifications.filter({
      $0.identifier == identifier
    }).first else { return nil }
    return matched.note
  }
  
}

extension AppDelegate: CLLocationManagerDelegate {
  
  public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    if region is CLCircularRegion {
      handleEvent(for: region)
    }
  }
  
  public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    if region is CLCircularRegion {
      handleEvent(for: region)
    }
  }
  
  func startMonitoring(geotification: Geotification) {
    if !CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
      showAlert(withTitle:"Error", message: "Geofencing is not supported on this device!")
      return
    }
    
    if CLLocationManager.authorizationStatus() != .authorizedAlways {
      let message = """
        Your geotification is saved but will only be activated once you grant
        Geotify permission to access the device location.
        """
      showAlert(withTitle:"Warning", message: message)
    }
    
    let fenceRegion = region(with: geotification)
    LocationService.shared.locationManager.startMonitoring(for: fenceRegion)
  }
  
  func stopMonitoring(geotification: Geotification) {
    for region in LocationService.shared.locationManager.monitoredRegions {
      guard let circularRegion = region as? CLCircularRegion, circularRegion.identifier == geotification.identifier else { continue }
      LocationService.shared.locationManager.stopMonitoring(for: circularRegion)
    }
  }
  
  func savedGeolocations() -> [Geotification] {
    let rj = CLLocationCoordinate2D(latitude: -22.944327372664198, longitude: -43.187060261401754)
    let radius = CLLocationDistance(exactly: 10000.0)!
    
    let identifier = NSUUID().uuidString
    let note = "Entrou no rj do appdelegate"
    let eventType: Geotification.EventType = .onEntry
    
    let geotification = Geotification(coordinate: rj, radius: radius, identifier: identifier, note: note, eventType: eventType)
    
    return [geotification]
  }
  
  
  func loadAllGeotifications() {
    LocationService.shared.geotifications.removeAll()
    let allGeotifications = savedGeolocations()
    allGeotifications.forEach { add($0) }
  }
  
  
  func add(_ geotification: Geotification) {
    LocationService.shared.geotifications.append(geotification)
    startMonitoring(geotification: geotification)
  }
  
  func remove(_ geotification: Geotification) {
    guard let index = LocationService.shared.geotifications.index(of: geotification) else { return }
    LocationService.shared.geotifications.remove(at: index)
  }
  
  func region(with geotification: Geotification) -> CLCircularRegion {
    let region = CLCircularRegion(center: geotification.coordinate, radius: geotification.radius, identifier: geotification.identifier)
    region.notifyOnEntry = (geotification.eventType == .onEntry)
    region.notifyOnExit = !region.notifyOnEntry
    return region
  }
  
  func showAlert(withTitle title: String?, message: String?) {
    DispatchQueue.main.async {
      let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
      let action = UIAlertAction(title: "OK", style: .cancel, handler: nil)
      alert.addAction(action)
      self.window?.rootViewController?.present(alert, animated: true, completion: nil)
    }
  }
  
  
  
}
