import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded(outlets: [Outlet], categories: [FoodCategory])
        case error(message: String)
    }
    
    private(set) var state: State = .idle
    private let repository: AppRepository
    
    init(repository: AppRepository) {
        self.repository = repository
    }
    
    func load() async {
        guard case .idle = state else { return }
        state = .loading
        
        do {
            async let outlets = repository.outlets.refreshOutlets()
            async let categories = repository.food.getCategories()
            
            let (outletsResult, categoriesResult) = try await (outlets, categories)
            state = .loaded(outlets: outletsResult, categories: categoriesResult)
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }
    
    func refresh() async {
        state = .idle
        await load()
    }
}
