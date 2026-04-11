import UIKit

final class GraveInfoCard: UIView {

    var onDismiss: (() -> Void)?

    private let nameLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 17, weight: .bold)
        lbl.textColor = .white
        lbl.numberOfLines = 1
        return lbl
    }()

    private let lifespanLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 13)
        lbl.textColor = UIColor.white.withAlphaComponent(0.8)
        return lbl
    }()

    private let sectionLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        lbl.textColor = UIColor.white.withAlphaComponent(0.6)
        return lbl
    }()

    private let bioLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 12)
        lbl.textColor = UIColor.white.withAlphaComponent(0.75)
        lbl.numberOfLines = 2
        lbl.isHidden = true
        return lbl
    }()

    private let dismissButton: UIButton = {
        let btn = UIButton(type: .system)
        let img = UIImage(systemName: "xmark.circle.fill",
                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 22))
        btn.setImage(img, for: .normal)
        btn.tintColor = UIColor.white.withAlphaComponent(0.7)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupView() {
        backgroundColor = UIColor.black.withAlphaComponent(0.7)
        layer.cornerRadius = 16
        layer.masksToBounds = true

        let blur = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blur)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, lifespanLabel, sectionLabel, bioLabel])
        textStack.axis    = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textStack)
        addSubview(dismissButton)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            textStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -8),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            dismissButton.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            dismissButton.widthAnchor.constraint(equalToConstant: 30),
            dismissButton.heightAnchor.constraint(equalToConstant: 30)
        ])

        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
    }

    func configure(with grave: GraveRecord) {
        nameLabel.text     = grave.fullName
        lifespanLabel.text = grave.lifespan

        var sectionParts = [grave.section]
        if let row = grave.row, let plot = grave.plot {
            sectionParts.append("Row \(row) · Plot \(plot)")
        }
        sectionLabel.text = sectionParts.joined(separator: " — ")

        if let bio = grave.biography, !bio.isEmpty {
            bioLabel.text   = bio
            bioLabel.isHidden = false
        } else {
            bioLabel.isHidden = true
        }
    }

    @objc private func dismissTapped() {
        onDismiss?()
    }
}
