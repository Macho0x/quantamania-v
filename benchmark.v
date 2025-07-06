import os
import time
import indicators

fn main() {
    mut times := []i64{}
    runs := 1000

    println('Benchmarking test_suite.v for $runs runs...')

    for i in 0 .. runs {
        start := time.now()
        // Run the test suite and suppress output
        _ := os.execute('v run test_suite.v > /dev/null 2>&1')
        elapsed := time.since(start).microseconds()
        times << elapsed
        if (i + 1) % 100 == 0 {
            println('Completed ${i + 1} runs...')
        }
    }

    times.sort()
    // Remove slowest 200 and fastest 200
    trimmed := times[200..800].clone()

    // Calculate mean
    mut sum := f64(0)
    for t in trimmed {
        sum += f64(t)
    }
    mean := sum / trimmed.len

    // Calculate standard deviation
    mut variance_sum := f64(0)
    for t in trimmed {
        diff := f64(t) - mean
        variance_sum += diff * diff
    }
    stddev := math.sqrt(variance_sum / trimmed.len)

    println('--- Benchmark Results ---')
    println('Runs: $runs')
    println('Trimmed runs: ${trimmed.len}')
    println('Mean: ${mean:.2f} μs')
    println('Std Dev: ${stddev:.2f} μs')
}
