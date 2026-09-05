import Foundation
import Observation

@MainActor
@Observable
final class FoodDetailViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded(FoodItem)
        case error(message: String)
    }
    
    private(set) var state: State = .idle
    private let repository: AppRepository
    let foodId: String
    
    init(foodId: String, repository: AppRepository) {
        self.foodId = foodId
        self.repository = repository
    }
    
    func load() async {
        guard case .idle = state else { return }
        state = .loading
        
        do {
            let item = try await repository.food.getFoodById(foodId)
            state = .loaded(item)
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }
    
    func toggleFavorite() async {
        guard case .loaded(var item) = state else { return }
        do {
            let newStatus = try await repository.food.toggleFavorite(item.id)
            item.isFavorite = newStatus
            state = .loaded(item)
        } catch {
            print("Failed to toggle favorite: \(error)")
        }
    }
}
