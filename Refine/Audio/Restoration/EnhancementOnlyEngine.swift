import Foundation

/// No reconstruction: the file goes straight to the repair, mix and master stages, after declipping if it's
/// clipped. For files whose highs are intact, or to improve a track without touching its spectrum.
struct EnhancementOnlyEngine: RestorationEngine {
    static let name = "Sans reconstruction"

    func restore(_ job: RestorationJob) -> AsyncThrowingStream<RestorationEvent, any Error> {
        .detachedRestoration { try Self.run(job, events: $0) }
    }

    static func run(_ job: RestorationJob, events: @escaping (RestorationEvent) -> Void) throws -> RestorationOutput {
        // Decoding is quick: most of the time goes to the second pass.
        try RestorationPipeline.run(job, engineName: name, engineShare: 0.3, events: events) { reader, sink in
            let declipper = job.settings.declip && job.analysis.isClipped ? Declipper() : nil
            // Rebuilt peaks need somewhere to go.
            let preGain: Float = declipper == nil ? 1 : 0.89

            while var block = try reader.read(maxFrames: 32_768) {
                try Task.checkCancellation()
                if let declipper {
                    for index in block.indices { declipper.process(&block[index]) }
                    block = block.map { $0.map { $0 * preGain } }
                }
                try sink(block)
            }
        }
    }
}
