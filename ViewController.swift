import UIKit
import ARKit
import CoreLocation
import Combine

final class ViewController: UIViewController {

    // MARK: - Components

    private let arManager       = ARSessionManager()
    private let locationManager = LocationManager()
    private let dataService     = GraveDataService()
    private let navState        = ARNavigationState()
    private let minimapVC       = MinimapViewController()
    private var cancellables    = Set<AnyCancellable>()

    // MARK: - HUD subviews

    private let trackingStatusLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.text            = "Initialising AR…"
        lbl.font            = .systemFont(ofSize: 12, weight: .semibold)
        lbl.textColor       = .white
        lbl.textAlignment   = .center
        lbl.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        lbl.layer.cornerRadius  = 10
        lbl.layer.masksToBounds = true
        return lbl
    }()

    private let distanceLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font            = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        lbl.textColor       = .white
        lbl.textAlignment   = .center
        lbl.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.85)
        lbl.layer.cornerRadius  = 12
        lbl.layer.masksToBounds = true
        lbl.isHidden = true
        return lbl
    }()

    private let searchButton: UIButton = {
        var cfg = UIButton.Configuration.filled()
        cfg.image = UIImage(systemName: "magnifyingglass",
                            withConfiguration: UIImage.SymbolConfiguration(
                                pointSize: 20, weight: .semibold))
        cfg.baseBackgroundColor = .systemBackground
        cfg.baseForegroundColor = .label
        cfg.cornerStyle = .capsule
        let btn = UIButton(configuration: cfg)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.layer.shadowColor   = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.3
        btn.layer.shadowOffset  = CGSize(width: 0, height: 3)
        btn.layer.shadowRadius  = 6
        return btn
    }()

    private let infoCard = GraveInfoCard()

    private let minimapShadowContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.shadowColor   = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.4
        v.layer.shadowOffset  = CGSize(width: 0, height: 4)
        v.layer.shadowRadius  = 8
        v.layer.cornerRadius  = 12
        return v
    }()

    // MARK: - Fallback banner
    //
    // Shown automatically when ARKit tracking is limited for > 3 seconds.
    // Contains a message explaining the degraded state and a direct button
    // to open the fullscreen map as a fallback navigation mode.

    private let fallbackBanner: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor   = UIColor.systemOrange.withAlphaComponent(0.93)
        v.layer.cornerRadius = 14
        v.layer.masksToBounds = true
        v.alpha   = 0
        v.isHidden = true
        return v
    }()

    private let fallbackMessageLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font          = .systemFont(ofSize: 13, weight: .semibold)
        lbl.textColor     = .white
        lbl.numberOfLines = 2
        lbl.text          = "AR-tracking is instabiel.\nGebruik de kaart om verder te navigeren."
        return lbl
    }()

    private let fallbackMapButton: UIButton = {
        var cfg = UIButton.Configuration.filled()
        cfg.title              = "Open kaart"
        cfg.baseBackgroundColor = .white
        cfg.baseForegroundColor = .systemOrange
        cfg.cornerStyle        = .capsule
        cfg.buttonSize         = .small
        let btn = UIButton(configuration: cfg)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let fallbackDismissButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setImage(UIImage(systemName: "xmark.circle.fill",
                             withConfiguration: UIImage.SymbolConfiguration(
                                pointSize: 20)), for: .normal)
        btn.tintColor = UIColor.white.withAlphaComponent(0.8)
        return btn
    }()

    /// Tracks how long tracking has been limited, used to delay banner appearance.
    private var trackingLimitedTimer: Timer?

    /// Whether the banner has been manually dismissed by the user this session.
    /// Prevents it from reappearing immediately after dismissal.
    private var bannerManuallDismissed = false

    // MARK: - Onboarding overlay
    //
    // Shown once, on first launch, when no grave has been selected yet.
    // Tells first-time users that the app navigates through the camera —
    // testing showed newcomers stayed on the minimap and never raised the
    // phone. Kept deliberately quiet and respectful for the cemetery setting:
    // no sound, no looping animation, just a single soft fade-in. Dismissal
    // is remembered in UserDefaults so it never interrupts a returning visitor.

    /// Bump the suffix if the onboarding copy/flow changes enough to warrant
    /// re-showing it to everyone.
    private static let onboardingSeenKey = "hasSeenAROnboarding_v1"

    private let onboardingOverlay: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        v.alpha    = 0
        v.isHidden = true
        return v
    }()

    private let onboardingCard: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor     = UIColor(white: 0.12, alpha: 0.97)
        v.layer.cornerRadius  = 18
        v.layer.masksToBounds = true
        return v
    }()

    private let onboardingIcon: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor   = .white
        iv.image = UIImage(systemName: "camera.viewfinder",
                           withConfiguration: UIImage.SymbolConfiguration(
                               pointSize: 38, weight: .regular))
        return iv
    }()

    private let onboardingTitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font          = .systemFont(ofSize: 17, weight: .semibold)
        lbl.textColor     = .white
        lbl.textAlignment = .center
        lbl.numberOfLines = 1
        // --- User-facing copy (Dutch, matching the fallback banner) ---
        lbl.text = "Navigeer met de camera"
        return lbl
    }()

    private let onboardingBodyLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font          = .systemFont(ofSize: 14, weight: .regular)
        lbl.textColor     = UIColor.white.withAlphaComponent(0.85)
        lbl.textAlignment = .center
        lbl.numberOfLines = 0
        // --- User-facing copy (Dutch, matching the fallback banner) ---
        lbl.text = "Houd je telefoon rechtop en richt de camera voor je. "
                 + "Een pijl en het grafpunt verschijnen dan in beeld en wijzen je de weg. "
                 + "De kaart linksonder blijft altijd beschikbaar."
        return lbl
    }()

    private let onboardingButton: UIButton = {
        var cfg = UIButton.Configuration.filled()
        cfg.title               = "Begrepen"
        cfg.baseBackgroundColor = .systemYellow
        cfg.baseForegroundColor = .black
        cfg.cornerStyle         = .capsule
        let btn = UIButton(configuration: cfg)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    // MARK: - Layout constants

    private let buttonSize:   CGFloat = 56
    private let buttonMargin: CGFloat = 20

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupMinimap()
        setupHUD()
        setupFallbackBanner()
        setupOnboardingOverlay()
        setupActions()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        arManager.startSession()
        locationManager.startUpdating()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showOnboardingIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arManager.pauseSession()
        locationManager.stopUpdating()
    }

    override var prefersStatusBarHidden: Bool        { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    // MARK: - Setup

    private func setupARView() {
        arManager.delegate       = self
        locationManager.delegate = self
        let sv = arManager.sceneView
        view.addSubview(sv)
        NSLayoutConstraint.activate([
            sv.topAnchor.constraint(equalTo: view.topAnchor),
            sv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sv.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupMinimap() {
        minimapVC.delegate = self
        addChild(minimapVC)
        view.addSubview(minimapShadowContainer)
        minimapShadowContainer.addSubview(minimapVC.view)
        minimapVC.view.translatesAutoresizingMaskIntoConstraints = false
        minimapVC.didMove(toParent: self)

        let s = minimapVC.cornerSize
        NSLayoutConstraint.activate([
            minimapShadowContainer.widthAnchor.constraint(equalToConstant: s.width),
            minimapShadowContainer.heightAnchor.constraint(equalToConstant: s.height),
            minimapShadowContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor,
                                                             constant: buttonMargin),
            minimapShadowContainer.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -buttonMargin - 70),
            minimapVC.view.topAnchor.constraint(equalTo: minimapShadowContainer.topAnchor),
            minimapVC.view.leadingAnchor.constraint(equalTo: minimapShadowContainer.leadingAnchor),
            minimapVC.view.trailingAnchor.constraint(equalTo: minimapShadowContainer.trailingAnchor),
            minimapVC.view.bottomAnchor.constraint(equalTo: minimapShadowContainer.bottomAnchor)
        ])
    }

    private func setupHUD() {
        view.addSubview(trackingStatusLabel)
        NSLayoutConstraint.activate([
            trackingStatusLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            trackingStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            trackingStatusLabel.heightAnchor.constraint(equalToConstant: 28),
            trackingStatusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 160)
        ])

        view.addSubview(distanceLabel)
        NSLayoutConstraint.activate([
            distanceLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            distanceLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor,
                                                     constant: -16),
            distanceLabel.heightAnchor.constraint(equalToConstant: 28),
            distanceLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])

        view.addSubview(searchButton)
        NSLayoutConstraint.activate([
            searchButton.widthAnchor.constraint(equalToConstant: buttonSize),
            searchButton.heightAnchor.constraint(equalToConstant: buttonSize),
            searchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor,
                                                    constant: -buttonMargin),
            searchButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -buttonMargin)
        ])

        infoCard.translatesAutoresizingMaskIntoConstraints = false
        infoCard.isHidden = true
        view.addSubview(infoCard)
        NSLayoutConstraint.activate([
            infoCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            infoCard.trailingAnchor.constraint(equalTo: searchButton.leadingAnchor,
                                               constant: -12),
            infoCard.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -buttonMargin)
        ])
        infoCard.onDismiss = { [weak self] in self?.clearSelectedGrave() }
    }

    // MARK: - Fallback banner setup

    private func setupFallbackBanner() {
        // Assemble banner subviews
        fallbackBanner.addSubview(fallbackMessageLabel)
        fallbackBanner.addSubview(fallbackMapButton)
        fallbackBanner.addSubview(fallbackDismissButton)

        NSLayoutConstraint.activate([
            fallbackDismissButton.topAnchor.constraint(equalTo: fallbackBanner.topAnchor,
                                                        constant: 10),
            fallbackDismissButton.trailingAnchor.constraint(equalTo: fallbackBanner.trailingAnchor,
                                                             constant: -10),
            fallbackDismissButton.widthAnchor.constraint(equalToConstant: 28),
            fallbackDismissButton.heightAnchor.constraint(equalToConstant: 28),

            fallbackMessageLabel.topAnchor.constraint(equalTo: fallbackBanner.topAnchor,
                                                       constant: 12),
            fallbackMessageLabel.leadingAnchor.constraint(equalTo: fallbackBanner.leadingAnchor,
                                                           constant: 14),
            fallbackMessageLabel.trailingAnchor.constraint(equalTo: fallbackDismissButton.leadingAnchor,
                                                            constant: -8),

            fallbackMapButton.topAnchor.constraint(equalTo: fallbackMessageLabel.bottomAnchor,
                                                    constant: 8),
            fallbackMapButton.leadingAnchor.constraint(equalTo: fallbackBanner.leadingAnchor,
                                                        constant: 14),
            fallbackMapButton.bottomAnchor.constraint(equalTo: fallbackBanner.bottomAnchor,
                                                       constant: -12)
        ])

        view.addSubview(fallbackBanner)
        NSLayoutConstraint.activate([
            fallbackBanner.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            fallbackBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            fallbackBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])

        fallbackMapButton.addTarget(self,
                                    action: #selector(fallbackMapButtonTapped),
                                    for: .touchUpInside)
        fallbackDismissButton.addTarget(self,
                                        action: #selector(fallbackDismissButtonTapped),
                                        for: .touchUpInside)
    }

    private func setupActions() {
        searchButton.addTarget(self, action: #selector(searchButtonTapped),
                               for: .touchUpInside)
    }

    // MARK: - Fallback banner logic

    /// Called when tracking becomes limited. Waits 3 seconds before showing
    /// the banner, to avoid flashing it on every brief tracking hiccup.
    private func startFallbackTimer() {
        guard !bannerManuallDismissed else { return }
        trackingLimitedTimer?.invalidate()
        trackingLimitedTimer = Timer.scheduledTimer(withTimeInterval: 3.0,
                                                     repeats: false) { [weak self] _ in
            self?.showFallbackBanner()
        }
    }

    private func cancelFallbackTimer() {
        trackingLimitedTimer?.invalidate()
        trackingLimitedTimer = nil
    }

    private func showFallbackBanner() {
        guard fallbackBanner.alpha == 0 else { return }
        fallbackBanner.isHidden = false
        fallbackBanner.transform = CGAffineTransform(translationX: 0, y: -20)
        UIView.animate(withDuration: 0.35, delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.3) {
            self.fallbackBanner.alpha = 1
            self.fallbackBanner.transform = .identity
        }
        // Dim AR nodes to signal unreliability
        arManager.setSceneOpacity(0.4)
    }

    private func hideFallbackBanner() {
        UIView.animate(withDuration: 0.25) {
            self.fallbackBanner.alpha = 0
            self.fallbackBanner.transform = CGAffineTransform(translationX: 0, y: -10)
        } completion: { _ in
            self.fallbackBanner.isHidden = true
        }
        // Restore AR node opacity
        arManager.setSceneOpacity(1.0)
    }

    @objc private func fallbackMapButtonTapped() {
        hideFallbackBanner()
        bannerManuallDismissed = true
        minimapVC.enterFullscreen()
    }

    @objc private func fallbackDismissButtonTapped() {
        hideFallbackBanner()
        bannerManuallDismissed = true
    }

    // MARK: - Onboarding overlay setup

    private func setupOnboardingOverlay() {
        onboardingCard.addSubview(onboardingIcon)
        onboardingCard.addSubview(onboardingTitleLabel)
        onboardingCard.addSubview(onboardingBodyLabel)
        onboardingCard.addSubview(onboardingButton)
        onboardingOverlay.addSubview(onboardingCard)
        view.addSubview(onboardingOverlay)

        NSLayoutConstraint.activate([
            onboardingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            onboardingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            onboardingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            onboardingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            onboardingCard.centerXAnchor.constraint(equalTo: onboardingOverlay.centerXAnchor),
            onboardingCard.centerYAnchor.constraint(equalTo: onboardingOverlay.centerYAnchor),
            onboardingCard.leadingAnchor.constraint(greaterThanOrEqualTo: onboardingOverlay.leadingAnchor,
                                                    constant: 32),
            onboardingCard.trailingAnchor.constraint(lessThanOrEqualTo: onboardingOverlay.trailingAnchor,
                                                     constant: -32),
            onboardingCard.widthAnchor.constraint(lessThanOrEqualToConstant: 320),

            onboardingIcon.topAnchor.constraint(equalTo: onboardingCard.topAnchor, constant: 26),
            onboardingIcon.centerXAnchor.constraint(equalTo: onboardingCard.centerXAnchor),
            onboardingIcon.heightAnchor.constraint(equalToConstant: 44),

            onboardingTitleLabel.topAnchor.constraint(equalTo: onboardingIcon.bottomAnchor, constant: 14),
            onboardingTitleLabel.leadingAnchor.constraint(equalTo: onboardingCard.leadingAnchor, constant: 22),
            onboardingTitleLabel.trailingAnchor.constraint(equalTo: onboardingCard.trailingAnchor, constant: -22),

            onboardingBodyLabel.topAnchor.constraint(equalTo: onboardingTitleLabel.bottomAnchor, constant: 10),
            onboardingBodyLabel.leadingAnchor.constraint(equalTo: onboardingCard.leadingAnchor, constant: 22),
            onboardingBodyLabel.trailingAnchor.constraint(equalTo: onboardingCard.trailingAnchor, constant: -22),

            onboardingButton.topAnchor.constraint(equalTo: onboardingBodyLabel.bottomAnchor, constant: 20),
            onboardingButton.leadingAnchor.constraint(equalTo: onboardingCard.leadingAnchor, constant: 22),
            onboardingButton.trailingAnchor.constraint(equalTo: onboardingCard.trailingAnchor, constant: -22),
            onboardingButton.heightAnchor.constraint(equalToConstant: 44),
            onboardingButton.bottomAnchor.constraint(equalTo: onboardingCard.bottomAnchor, constant: -20)
        ])

        onboardingButton.addTarget(self, action: #selector(dismissOnboarding),
                                   for: .touchUpInside)

        // Tapping the dimmed backdrop also dismisses, matching the gentle tone.
        // cancelsTouchesInView = false so the button still receives its tap.
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissOnboarding))
        tap.cancelsTouchesInView = false
        onboardingOverlay.addGestureRecognizer(tap)
    }

    // MARK: - Onboarding overlay logic

    /// Fades the overlay in only on first launch, and only while nothing is
    /// being navigated to. Once dismissed it is remembered and never shown again.
    private func showOnboardingIfNeeded() {
        let alreadySeen = UserDefaults.standard.bool(forKey: Self.onboardingSeenKey)
        guard !alreadySeen,
              navState.selectedGrave == nil,
              onboardingOverlay.isHidden
        else { return }

        onboardingOverlay.alpha    = 0
        onboardingOverlay.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.onboardingOverlay.alpha = 1
        }
    }

    @objc private func dismissOnboarding() {
        guard !onboardingOverlay.isHidden else { return }
        UserDefaults.standard.set(true, forKey: Self.onboardingSeenKey)
        UIView.animate(withDuration: 0.25, animations: {
            self.onboardingOverlay.alpha = 0
        }, completion: { _ in
            self.onboardingOverlay.isHidden = true
        })
    }

    // MARK: - Data

    private func loadData() {
        Task { @MainActor in
            await dataService.load()
            minimapVC.graves = dataService.allGraves
            if let err = dataService.loadError {
                showErrorAlert(message: err.localizedDescription)
            }
        }
    }

    // MARK: - Search

    @objc private func searchButtonTapped() {
        let vc = SearchViewController()
        vc.dataService = dataService
        vc.delegate    = self
        let nav = UINavigationController(rootViewController: vc)
        if let sheet = nav.sheetPresentationController {
            sheet.detents               = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        present(nav, animated: true)
    }

    // MARK: - Navigation

    func navigateTo(grave: GraveRecord) {
        navState.selectedGrave  = grave
        minimapVC.selectedGrave = grave
        arManager.startNavigation(to: grave)
        updateDistanceLabel(for: grave)
        infoCard.configure(with: grave)
        showInfoCard()
        minimapVC.centreMap(on: grave.coordinate, span: 0.0005)
        // Reset manual dismiss so banner can show again for new navigation
        bannerManuallDismissed = false
    }

    private func clearSelectedGrave() {
        navState.selectedGrave    = nil
        navState.distanceToTarget = nil
        minimapVC.selectedGrave   = nil
        arManager.stopNavigation()
        distanceLabel.isHidden = true
        hideInfoCard()
        hideFallbackBanner()
        cancelFallbackTimer()
    }

    // MARK: - Distance label

    private func updateDistanceLabel(for grave: GraveRecord) {
        guard let dist = locationManager.distance(to: grave) else { return }
        navState.distanceToTarget = dist
        let text = dist < 1000
            ? String(format: " %.0f m ", dist)
            : String(format: " %.1f km ", dist / 1000)
        distanceLabel.text    = text
        distanceLabel.isHidden = false
    }

    // MARK: - Info card

    private func showInfoCard() {
        infoCard.isHidden  = false
        infoCard.alpha     = 0
        infoCard.transform = CGAffineTransform(translationX: 0, y: 20)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.infoCard.alpha     = 1
            self.infoCard.transform = .identity
        }
    }

    private func hideInfoCard() {
        UIView.animate(withDuration: 0.2) {
            self.infoCard.alpha     = 0
            self.infoCard.transform = CGAffineTransform(translationX: 0, y: 20)
        } completion: { _ in self.infoCard.isHidden = true }
    }

    // MARK: - Errors

    private func showErrorAlert(message: String) {
        let a = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}

// MARK: - ARSessionManagerDelegate

extension ViewController: ARSessionManagerDelegate {

    func arSessionManager(_ manager: ARSessionManager, didUpdateFrame frame: ARFrame) {}

    func arSessionManager(_ manager: ARSessionManager,
                          didChangeTrackingState state: ARCamera.TrackingState) {
        DispatchQueue.main.async { self.handleTrackingStateChange(state) }
    }

    private func handleTrackingStateChange(_ state: ARCamera.TrackingState) {
        switch state {
        case .notAvailable:
            trackingStatusLabel.text = "AR Unavailable"
            trackingStatusLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.7)
            // Start fallback timer immediately when AR is completely unavailable
            if navState.selectedGrave != nil { startFallbackTimer() }

        case .limited(let reason):
            let msg: String
            switch reason {
            case .initializing:
                msg = "Initialising…"
                // Do not show fallback during normal startup
            case .insufficientFeatures:
                msg = "Insufficient Features"
                if navState.selectedGrave != nil { startFallbackTimer() }
            case .excessiveMotion:
                msg = "Slow Down"
                // Excessive motion is brief, no fallback needed
            case .relocalizing:
                msg = "Relocalising…"
                if navState.selectedGrave != nil { startFallbackTimer() }
            @unknown default:
                msg = "Limited Tracking"
                if navState.selectedGrave != nil { startFallbackTimer() }
            }
            trackingStatusLabel.text = msg
            trackingStatusLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.7)
            trackingStatusLabel.alpha = 1

        case .normal:
            trackingStatusLabel.text = "AR Active ✓"
            trackingStatusLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.7)
            // Cancel any pending fallback timer and hide the banner
            cancelFallbackTimer()
            hideFallbackBanner()
            // Reset manual dismiss flag so future degradation can show banner
            bannerManuallDismissed = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                UIView.animate(withDuration: 0.5) { self.trackingStatusLabel.alpha = 0.3 }
            }
        }
    }
}

// MARK: - LocationManagerDelegate

extension ViewController: LocationManagerDelegate {

    func locationManager(_ manager: LocationManager,
                         didUpdateLocation location: CLLocation) {
        navState.userLocation = location
        if location.horizontalAccuracy < 20 {
            arManager.setOrigin(coordinate: location.coordinate)
        }
        if let grave = navState.selectedGrave {
            updateDistanceLabel(for: grave)
        }
        if !minimapVC.isFullscreen {
            minimapVC.centreMap(on: location.coordinate, span: 0.001)
        }
    }

    func locationManager(_ manager: LocationManager,
                         didUpdateHeading heading: CLHeading) {
        navState.heading = heading.trueHeading
    }

    func locationManager(_ manager: LocationManager, didFailWithError error: Error) {
        print("[VC] Location error: \(error.localizedDescription)")
    }
}

// MARK: - SearchViewControllerDelegate

extension ViewController: SearchViewControllerDelegate {
    func searchViewController(_ vc: SearchViewController,
                               didSelectGrave grave: GraveRecord) {
        navigateTo(grave: grave)
    }
}

// MARK: - MinimapViewControllerDelegate

extension ViewController: MinimapViewControllerDelegate {
    func minimapViewController(_ vc: MinimapViewController,
                                didSelectGrave grave: GraveRecord) {
        navigateTo(grave: grave)
    }
}
