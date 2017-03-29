#!/bin/sh

if [ ! -e gyb.py ]; then
    curl -L --remote-name https://github.com/apple/swift/raw/master/utils/gyb.py
fi

echo 'Generating `Orderly.swift`...'
python gyb.py --line-directive '' -o Orderly.swift.split Orderly.swift.split.gyb

python split.py Orderly.swift.split

mv *.swift ../Sources/Orderly
rm Orderly.swift.split

echo 'Done!'