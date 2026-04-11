import UIKit

protocol SearchViewControllerDelegate: AnyObject {
    func searchViewController(_ vc: SearchViewController,
                              didSelectGrave grave: GraveRecord)
}

final class SearchViewController: UIViewController {

    weak var delegate: SearchViewControllerDelegate?
    var dataService: GraveDataService?
    
    private let searchController = UISearchController(searchResultsController: nil)
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private var results: [GraveRecord] = []
    private var showingAll: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAppearance()
        setupSearchController()
        setupTableView()
        loadInitialResults()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchController.searchBar.becomeFirstResponder()
    }

    private func setupAppearance() {
        view.backgroundColor = .systemBackground
        title = "Search grave"
        navigationItem.largeTitleDisplayMode = .never
    }

    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Name or section…"
        searchController.searchBar.returnKeyType = .search
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private func setupTableView() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.register(GraveResultCell.self,
                           forCellReuseIdentifier: GraveResultCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadInitialResults() {
        results = dataService?.allGraves ?? []
        tableView.reloadData()
    }
}

extension SearchViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text ?? ""
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            results = dataService?.allGraves ?? []
            showingAll = true
        } else {
            results = dataService?.search(query: query) ?? []
            showingAll = false
        }
        tableView.reloadData()
    }
}

extension SearchViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.isEmpty ? 1 : results.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if results.isEmpty {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = "No results found"
            cell.textLabel?.textColor = .secondaryLabel
            cell.textLabel?.textAlignment = .center
            cell.isUserInteractionEnabled = false
            return cell
        }

        let cell = tableView.dequeueReusableCell(
            withIdentifier: GraveResultCell.reuseID,
            for: indexPath) as! GraveResultCell
        cell.configure(with: results[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {
        showingAll ? "All graves (\(results.count))" : "Results (\(results.count))"
    }
}

extension SearchViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !results.isEmpty else { return }
        let grave = results[indexPath.row]
        dismiss(animated: true) { [weak self] in
            guard let self else { return }
            self.delegate?.searchViewController(self, didSelectGrave: grave)
        }
    }
}

final class GraveResultCell: UITableViewCell {

    static let reuseID = "GraveResultCell"

    private let nameLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 16, weight: .semibold)
        lbl.textColor = .label
        return lbl
    }()

    private let lifespanLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 13)
        lbl.textColor = .secondaryLabel
        return lbl
    }()

    private let sectionLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        lbl.textColor = .tertiaryLabel
        return lbl
    }()

    private lazy var stack: UIStackView = {
        let sv = UIStackView(arrangedSubviews: [nameLabel, lifespanLabel, sectionLabel])
        sv.axis = .vertical
        sv.spacing = 2
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
        accessoryType = .disclosureIndicator
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func configure(with grave: GraveRecord) {
        nameLabel.text     = grave.fullName
        lifespanLabel.text = grave.lifespan

        var sectionParts = [grave.section]
        if let row = grave.row, let plot = grave.plot {
            sectionParts.append("Row \(row) · Plot \(plot)")
        }
        sectionLabel.text = sectionParts.joined(separator: " — ")
    }
}
