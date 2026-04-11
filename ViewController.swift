import UIKit
import ARKit
import CoreLocation
import Combine

final class ViewController: UIViewController {

    private let arManager       = ARSessionManager()
    private let locationManager = LocationManager()
    private let dataService     = GraveDataService()
    private let navState        = ARNavigationState()
    private let minimapVC       = MinimapViewController()
    private var cancellables    = Set<AnyCancellable>()

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

    private let buttonSize:   CGFloat = 56
    private let buttonMargin: CGFloat = 20

    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupMinimap()
        setupHUD()
        setupActions()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        arManager.startSession()
        locationManager.startUpdating()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arManager.pauseSession()
        locationManager.stopUpdating()
    }

    override var prefersStatusBarHidden: Bool        { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    
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

    private func setupActions() {
        searchButton.addTarget(self, action: #selector(searchButtonTapped),
                               for: .touchUpInside)
    }

    private func loadData() {
        Task { @MainActor in
            await dataService.load()
            minimapVC.graves = dataService.allGraves
            if let err = dataService.loadError {
                showErrorAlert(message: err.localizedDescription)
            }
        }
    }

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

    func navigateTo(grave: GraveRecord) {
        navState.selectedGrave  = grave
        minimapVC.selectedGrave = grave

        arManager.startNavigation(to: grave)

        updateDistanceLabel(for: grave)

        infoCard.configure(with: grave)
        showInfoCard()
        minimapVC.centreMap(on: grave.coordinate, span: 0.0005)
    }

    private func clearSelectedGrave() {
        navState.selectedGrave    = nil
        navState.distanceToTarget = nil
        minimapVC.selectedGrave   = nil
        arManager.stopNavigation()
        distanceLabel.isHidden = true
        hideInfoCard()
    }

    private func updateDistanceLabel(for grave: GraveRecord) {
        guard let dist = locationManager.distance(to: grave) else { return }
        navState.distanceToTarget = dist
        let text = dist < 1000
            ? String(format: " %.0f m ", dist)
            : String(format: " %.1f km ", dist / 1000)
        distanceLabel.text    = text
        distanceLabel.isHidden = false
    }

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

    private func showErrorAlert(message: String) {
        let a = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}

extension ViewController: ARSessionManagerDelegate {

    func arSessionManager(_ manager: ARSessionManager, didUpdateFrame frame: ARFrame) {}

    func arSessionManager(_ manager: ARSessionManager,
                          didChangeTrackingState state: ARCamera.TrackingState) {
        DispatchQueue.main.async { self.updateTrackingLabel(for: state) }
    }

    private func updateTrackingLabel(for state: ARCamera.TrackingState) {
        switch state {
        case .notAvailable:
            trackingStatusLabel.text = "AR Unavailable"
            trackingStatusLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.7)
        case .limited(let reason):
            let msg: String
            switch reason {
            case .initializing:         msg = "Initialising…"
            case .insufficientFeatures: msg = "Insufficient Features"
            case .excessiveMotion:      msg = "Slow Down"
            case .relocalizing:         msg = "Relocalising…"
            @unknown default:           msg = "Limited Tracking"
            }
            trackingStatusLabel.text = msg
            trackingStatusLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.7)
        case .normal:
            trackingStatusLabel.text = "AR Active ✓"
            trackingStatusLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.7)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                UIView.animate(withDuration: 0.5) { self.trackingStatusLabel.alpha = 0.3 }
            }
        }
    }
}

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

extension ViewController: SearchViewControllerDelegate {
    func searchViewController(_ vc: SearchViewController,
                               didSelectGrave grave: GraveRecord) {
        navigateTo(grave: grave)
    }
}

extension ViewController: MinimapViewControllerDelegate {
    func minimapViewController(_ vc: MinimapViewController,
                                didSelectGrave grave: GraveRecord) {
        navigateTo(grave: grave)
    }
}
