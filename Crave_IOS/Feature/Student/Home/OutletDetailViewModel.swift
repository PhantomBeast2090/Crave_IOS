import Foundation
import Observation

@MainActor
@Observable
final class OutletDetailViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded(outlet: Outlet, menu: [FoodItem])
        case error(message: String)
    }
    
    private(set) var state: State = .idle
    private let repository: AppRepository
    let outletId: String
    
    init(outletId: String, repository: AppRepository) {
        self.outletId = outletId
        self.repository = repository
    }
    
    func load() async {
        guard case .idle = state else { return }
        state = .loading
        
        do {
            async let outlet = repository.outlets.getOutletById(outletId)
            async let menu = repository.food.getMenuByOutlet(outletId)
            
            let (outletResult, menuResult) = try await (outlet, menu)
            state = .loaded(outlet: outletResult, menu: menuResult)
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }
}
