# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] - 2026-03-14

### Added
- Initial implementation of intrinsic curiosity engine
- Wonder lifecycle: create, explore, resolve with reward calculation
- Gap detector: identifies unknown, uncertain, contradictory, and incomplete knowledge gaps
- WonderStore with domain-balanced retrieval, salience decay, and pruning
- Curiosity intensity metric based on active wonder count
- Agenda formation from top wonders for dream cycle integration
- Client class with full runner delegation
- 59 RSpec examples covering all components
