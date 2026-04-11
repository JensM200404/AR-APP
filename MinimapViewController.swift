import UIKit
import MapKit

protocol MinimapViewControllerDelegate: AnyObject {
    func minimapViewController(_ vc: MinimapViewController,
                               didSelectGrave grave: GraveRecord)
}

final class MinimapViewController: UIViewController {

    weak var delegate: MinimapViewControllerDelegate?

    var graves: [GraveRecord] = [] {
        didSet { updateAnnotations() }
    }

    var selectedGrave: GraveRecord? {
        didSet { updateSelectedAnnotation() }
    }

    private let mapView: MKMapView = {
        let map = MKMapView()
        map.translatesAutoresizingMaskIntoConstraints = false
        map.mapType = .satellite
        map.showsUserLocation = true
        map.showsCompass = false
        map.isRotateEnabled = false
        return map
    }()

    let cornerSize = CGSize(width: 120, height: 120)
    private let cornerCornerRadius: CGFloat = 12

    private(set) var isFullscreen: Bool = false

    private lazy var tapGesture = UITapGestureRecognizer(
        target: self, action: #selector(handleTap(_:)))

    private var annotationsByID: [String: GraveAnnotation] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()

        setupMapView()
        setupCornerAppearance()
        view.addGestureRecognizer(tapGesture)
    }

    private func setupMapView() {
        view.addSubview(mapView)
        mapView.delegate = self

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        mapView.register(MKMarkerAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: "gravePin")
    }

    private func setupCornerAppearance() {
        view.layer.cornerRadius = cornerCornerRadius
        view.layer.masksToBounds = true
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        view.layer.borderWidth = 1
    }

    @objc private func handleTap(_ sender: UITapGestureRecognizer) {
        isFullscreen ? exitFullscreen() : enterFullscreen()
    }

    func enterFullscreen() {
        guard !isFullscreen, let parent = parent else { return }
        isFullscreen = true

        let currentFrame = view.convert(view.bounds, to: parent.view)
        parent.view.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = true
        view.frame = currentFrame

        UIView.animate(withDuration: 0.38,
                       delay: 0,
                       usingSpringWithDamping: 0.9,
                       initialSpringVelocity: 0.2,
                       options: .curveEaseInOut) {
            self.view.frame = parent.view.bounds
            self.view.layer.cornerRadius = 0
        } completion: { _ in
            self.mapView.isScrollEnabled  = true
            self.mapView.isZoomEnabled    = true
            self.mapView.isRotateEnabled  = true
            self.zoomToFitAllAnnotations()
            self.showCloseButton()
        }
    }

    func exitFullscreen() {
        guard isFullscreen, let parent = parent else { return }
        isFullscreen = false
        hideCloseButton()

        mapView.isScrollEnabled  = false
        mapView.isZoomEnabled    = false
        mapView.isRotateEnabled  = false

        let targetFrame = cornerFrame(in: parent.view)

        UIView.animate(withDuration: 0.35,
                       delay: 0,
                       usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.3,
                       options: .curveEaseInOut) {
            self.view.frame = targetFrame
            self.view.layer.cornerRadius = self.cornerCornerRadius
        } completion: { _ in
            guard let container = parent.view.subviews.first(where: {
                $0.subviews.isEmpty == false &&
                $0 !== self.view &&
                $0.frame.size == targetFrame.size
            }) else { return }

            self.view.removeFromSuperview()
            self.view.frame = container.bounds
            container.addSubview(self.view)
            self.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                self.view.topAnchor.constraint(equalTo: container.topAnchor),
                self.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                self.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                self.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])

            if let userCoord = self.mapView.userLocation.location?.coordinate {
                self.centreMap(on: userCoord, span: 0.001)
            }
        }
    }

    private lazy var closeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("✕  Close map", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        btn.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        btn.layer.cornerRadius = 18
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        btn.alpha = 0
        return btn
    }()

    private var closeButtonConstraints: [NSLayoutConstraint] = []

    private func showCloseButton() {
        view.addSubview(closeButton)
        closeButtonConstraints = [
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor,
                                             constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            closeButton.widthAnchor.constraint(equalToConstant: 130)
        ]
        NSLayoutConstraint.activate(closeButtonConstraints)
        UIView.animate(withDuration: 0.2) { self.closeButton.alpha = 1 }
    }

    private func hideCloseButton() {
        UIView.animate(withDuration: 0.15) { self.closeButton.alpha = 0 } completion: { _ in
            self.closeButton.removeFromSuperview()
            NSLayoutConstraint.deactivate(self.closeButtonConstraints)
        }
    }

    @objc private func closeButtonTapped() { exitFullscreen() }

    private func updateAnnotations() {
        let newIDs = Set(graves.map(\.id))
        let toRemove = annotationsByID.filter { !newIDs.contains($0.key) }.values
        mapView.removeAnnotations(Array(toRemove))
        toRemove.forEach { annotationsByID.removeValue(forKey: $0.grave.id) }

        let existingIDs = Set(annotationsByID.keys)
        let toAdd = graves.filter { !existingIDs.contains($0.id) }
        let newAnnotations = toAdd.map { GraveAnnotation(grave: $0) }
        newAnnotations.forEach { annotationsByID[$0.grave.id] = $0 }
        mapView.addAnnotations(newAnnotations)
    }

    private func updateSelectedAnnotation() {
        mapView.deselectAnnotation(nil, animated: false)

        if let grave = selectedGrave,
           let annotation = annotationsByID[grave.id] {
            mapView.selectAnnotation(annotation, animated: true)
            centreMap(on: grave.coordinate, span: 0.0005)
        }
    }

    func centreMap(on coordinate: CLLocationCoordinate2D, span: Double) {
        let region = MKCoordinateRegion(center: coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: span,
                                                               longitudeDelta: span))
        mapView.setRegion(region, animated: true)
    }

    private func zoomToFitAllAnnotations() {
        guard !mapView.annotations.isEmpty else { return }
        mapView.showAnnotations(mapView.annotations, animated: true)
    }

    func cornerFrame(in parentView: UIView) -> CGRect {
        let safeBottom = parentView.safeAreaInsets.bottom
        let margin: CGFloat = 16
        return CGRect(
            x: margin,
            y: parentView.bounds.height - cornerSize.height - safeBottom - margin - 80,
            width: cornerSize.width,
            height: cornerSize.height
        )
    }
}

extension MinimapViewController: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView,
                 viewFor annotation: MKAnnotation) -> MKAnnotationView? {

        guard let graveAnnotation = annotation as? GraveAnnotation else { return nil }

        let view = mapView.dequeueReusableAnnotationView(
            withIdentifier: "gravePin",
            for: annotation) as! MKMarkerAnnotationView

        if graveAnnotation.grave.id == selectedGrave?.id {
            view.markerTintColor = .systemYellow
            view.glyphImage = UIImage(systemName: "star.fill")
        } else {
            view.markerTintColor = .white
            view.glyphImage = UIImage(systemName: "cross.fill")
        }

        view.canShowCallout = true
        let detailBtn = UIButton(type: .detailDisclosure)
        view.rightCalloutAccessoryView = detailBtn

        return view
    }

    func mapView(_ mapView: MKMapView,
                 annotationView view: MKAnnotationView,
                 calloutAccessoryControlTapped control: UIControl) {
        guard let graveAnnotation = view.annotation as? GraveAnnotation else { return }
        delegate?.minimapViewController(self, didSelectGrave: graveAnnotation.grave)
        exitFullscreen()
    }
}
