import UIKit
import Capacitor
import HealthKit
import CoreMotion
import WebKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // 每次回到前台都重新拉起步数监听，并补发冷启动时排队的健康数据
        startPedometer()
        flushPending()
        tuneWebView()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        pedometer?.stopUpdates()
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // twfit://sync?... 由快捷指令回传真实健康数据
        if url.scheme == "twfit" {
            handleSyncURL(url)
            return true
        }
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Called when the app was launched with an activity, including Universal Links.
        // Feel free to add additional processing here, but if you want the App API to support
        // tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

    // MARK: - 实时步数（CoreMotion，不需要 HealthKit 权限）
    private var pedometer: CMPedometer?
    private var pendingPayload: [String: Any]?

    private func bridgeWebView() -> WKWebView? {
        return (window?.rootViewController as? CAPBridgeViewController)?.webView
    }

    private func eval(_ js: String) {
        DispatchQueue.main.async {
            self.bridgeWebView()?.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    /// 关掉 WebView 的“网页手感”：双击/捏合缩放、橡皮筋回弹、长按链接预览
    private func tuneWebView() {
        guard let wv = bridgeWebView() else { return }
        wv.scrollView.pinchGestureRecognizer?.isEnabled = false
        wv.scrollView.bouncesZoom = false
        wv.scrollView.alwaysBounceVertical = false
        wv.scrollView.alwaysBounceHorizontal = false
        wv.scrollView.decelerationRate = .fast
        wv.scrollView.showsVerticalScrollIndicator = false
        wv.allowsLinkPreview = false
    }

    private func startPedometer() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        if pedometer == nil { pedometer = CMPedometer() }
        let from = Calendar.current.startOfDay(for: Date())
        pedometer?.startUpdates(from: from) { [weak self] data, error in
            guard let self = self, let d = data else { return }
            var p: [String: Any] = [
                "steps": d.numberOfSteps.intValue,
                "distance": d.distance?.doubleValue ?? 0,
                "floors": d.floorsAscended?.intValue ?? 0,
                "ts": Date().timeIntervalSince1970
            ]
            if let pace = d.currentPace, pace.doubleValue > 0 { p["pace"] = pace.doubleValue }
            if let cad = d.currentCadence, cad.doubleValue > 0 { p["cadence"] = cad.doubleValue }
            if let json = try? JSONSerialization.data(withJSONObject: p),
               let s = String(data: json, encoding: .utf8) {
                self.eval("window.TWLive&&window.TWLive.onSteps(\(s))")
            }
        }
    }

    private func handleSyncURL(_ url: URL) {
        var dict: [String: String] = [:]
        if let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            for it in items { if let v = it.value { dict[it.name] = v } }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let s = String(data: data, encoding: .utf8) else { return }
        pendingPayload = dict
        eval("window.TWLive&&window.TWLive.onHealth(\(s))")
    }

    private func flushPending() {
        guard let dict = pendingPayload,
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let s = String(data: data, encoding: .utf8) else { return }
        pendingPayload = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.eval("window.TWLive&&window.TWLive.onHealth(\(s))")
        }
    }

}

// MARK: - 健康数据桥（HealthKit）
// 说明：需要付费开发者账号勾选 HealthKit 能力；免费签名下调用会被系统拒绝，
// 前端会自动降级并在“生物感知 → 设备与数据同步”里给出提示。
@objc(HealthBridgePlugin)
public class HealthBridgePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "HealthBridgePlugin"
    public let jsName = "HealthBridge"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "authorize", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "query", returnType: CAPPluginReturnPromise)
    ]

    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var set = Set<HKObjectType>()
        let ids: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .basalEnergyBurned,
            .heartRate, .restingHeartRate, .heartRateVariabilitySDNN, .bodyMass
        ]
        for id in ids {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { set.insert(t) }
        }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { set.insert(sleep) }
        set.insert(HKObjectType.workoutType())
        return set
    }

    @objc public func authorize(_ call: CAPPluginCall) {
        guard HKHealthStore.isHealthDataAvailable() else {
            call.reject("HEALTH_UNAVAILABLE")
            return
        }
        store.requestAuthorization(toShare: [], read: readTypes) { granted, error in
            if let error = error {
                call.reject("AUTH_FAILED: \(error.localizedDescription)")
                return
            }
            call.resolve(["granted": granted])
        }
    }

    @objc public func query(_ call: CAPPluginCall) {
        guard HKHealthStore.isHealthDataAvailable() else {
            call.reject("HEALTH_UNAVAILABLE")
            return
        }
        let start = Calendar.current.startOfDay(for: Date())
        var steps = 0.0, active = 0.0, hr = 0.0, hrv = 0.0, weight = 0.0, sleepMinutes = 0.0
        var workouts: [[String: Any]] = []
        let group = DispatchGroup()

        group.enter()
        sum(.stepCount, unit: .count(), from: start) { v in steps = v; group.leave() }

        group.enter()
        sum(.activeEnergyBurned, unit: .kilocalorie(), from: start) { v in active = v; group.leave() }

        group.enter()
        latest(.heartRate, unit: HKUnit(from: "count/min")) { v in hr = v; group.leave() }

        group.enter()
        latest(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli)) { v in hrv = v; group.leave() }

        group.enter()
        latest(.bodyMass, unit: .gramUnit(with: .kilo)) { v in weight = v; group.leave() }

        group.enter()
        sleepLast24 { v in sleepMinutes = v; group.leave() }

        group.enter()
        recentWorkouts { list in workouts = list; group.leave() }

        group.notify(queue: .main) {
            call.resolve([
                "steps": Int(steps.rounded()),
                "activeEnergy": active,
                "heartRate": hr,
                "hrv": hrv,
                "weight": weight,
                "sleepMinutes": sleepMinutes,
                "workouts": workouts
            ])
        }
    }

    // MARK: - Helpers

    private func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from: Date,
                     completion: @escaping (Double) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else {
            completion(0); return
        }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: Date(), options: .strictStartDate)
        let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                  options: .cumulativeSum) { _, result, _ in
            completion(result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
        }
        store.execute(q)
    }

    private func latest(_ id: HKQuantityTypeIdentifier, unit: HKUnit,
                        completion: @escaping (Double) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else {
            completion(0); return
        }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1,
                              sortDescriptors: [sort]) { _, samples, _ in
            completion((samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit) ?? 0)
        }
        store.execute(q)
    }

    private func sleepLast24(completion: @escaping (Double) -> Void) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(0); return
        }
        let from = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: from, end: Date(), options: .strictStartDate)
        let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 200,
                              sortDescriptors: nil) { _, samples, _ in
            var minutes = 0.0
            for case let s as HKCategorySample in (samples ?? []) {
                // 1 = asleepUnspecified, 3... = core/deep/REM
                if s.value == 1 || s.value >= 3 {
                    minutes += s.endDate.timeIntervalSince(s.startDate) / 60
                }
            }
            completion(minutes)
        }
        store.execute(q)
    }

    private func recentWorkouts(completion: @escaping ([[String: Any]]) -> Void) {
        let from = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: from, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let q = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate,
                              limit: 20, sortDescriptors: [sort]) { _, samples, _ in
            let list: [[String: Any]] = (samples as? [HKWorkout] ?? []).map { w in
                [
                    "type": String(describing: w.workoutActivityType),
                    "minutes": w.duration / 60,
                    "kcal": (w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0),
                    "source": w.sourceRevision.source.name,
                    "end": w.endDate.timeIntervalSince1970
                ]
            }
            completion(list)
        }
        store.execute(q)
    }
}
