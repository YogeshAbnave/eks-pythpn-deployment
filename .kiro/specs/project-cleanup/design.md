# Design Document

## Overview

This design outlines the systematic cleanup and optimization of the CloudAge Education App project. The cleanup will focus on removing redundant files, consolidating configurations, optimizing code, and standardizing UI components while preserving all core functionality.

## Architecture

The cleanup will maintain the existing Streamlit-based architecture with the following components:
- **Frontend**: Streamlit pages (Home.py, Create/Show/Complete Assignments)
- **Backend Services**: AWS Bedrock, DynamoDB, S3
- **Deployment**: Docker containerization with ECS Fargate
- **Infrastructure**: AWS services managed via deployment scripts

## Components and Interfaces

### File Structure Optimization
- **Consolidate Task Definitions**: Keep `ecs-task.json` (more complete) and remove `aws/task-definition.json`
- **Standardize UI Components**: Utilize `components/ui_template.py` across all pages
- **Clean Deployment Scripts**: Maintain both PowerShell and Bash versions for cross-platform support
- **Remove System Files**: Delete `.DS_Store` and other OS-specific artifacts

### Code Optimization Areas

#### 1. Import Cleanup
- Remove unused imports in all Python files
- Consolidate common imports into shared modules
- Optimize import order following PEP 8 standards

#### 2. UI Standardization
- Replace duplicate Streamlit configuration code with `ui_template.setup_page()`
- Use `ui_template.hide_streamlit_chrome()` instead of inline CSS
- Apply `ui_template.render_header()` for consistent page headers

#### 3. Configuration Consolidation
- Merge environment variables from both task definitions
- Standardize AWS resource names and configurations
- Remove redundant policy files

## Data Models

### Files to Remove
```
- .DS_Store (macOS system file)
- aws/task-definition.json (duplicate with different settings)
- temp-*.png files (runtime generated, should not be in repo)
- Unused policy files (if any are not referenced)
```

### Files to Optimize
```
- All Python files in pages/ (remove unused imports, standardize UI)
- components/ui_template.py (ensure it's fully utilized)
- ecs-task.json (consolidate environment variables)
- Dockerfile (optimize if needed)
```

## Error Handling

### Cleanup Safety Measures
1. **Backup Strategy**: Document all changes for potential rollback
2. **Functionality Preservation**: Test each page after UI standardization
3. **Configuration Validation**: Ensure consolidated task definition works correctly
4. **Dependency Verification**: Confirm all imports are actually unused before removal

### Risk Mitigation
- **Incremental Changes**: Apply cleanup in small, testable chunks
- **Functionality Testing**: Verify each component works after modification
- **Rollback Plan**: Keep track of removed files and changes

## Testing Strategy

### Validation Steps
1. **Syntax Validation**: Use getDiagnostics to check for Python syntax errors
2. **Import Verification**: Ensure removed imports don't break functionality
3. **UI Consistency**: Verify all pages render correctly with standardized components
4. **Configuration Testing**: Validate consolidated task definition structure

### Test Coverage
- **Page Rendering**: Test all Streamlit pages load without errors
- **Component Integration**: Verify ui_template functions work across all pages
- **AWS Configuration**: Validate task definition JSON structure
- **Docker Build**: Ensure Dockerfile still builds successfully

## Implementation Phases

### Phase 1: File Cleanup
- Remove system files (.DS_Store)
- Delete duplicate task definition
- Remove temporary image files

### Phase 2: Code Optimization
- Clean up unused imports
- Remove unused variables and functions
- Consolidate repeated code patterns

### Phase 3: UI Standardization
- Update all pages to use ui_template components
- Remove duplicate Streamlit configuration code
- Standardize page headers and styling

### Phase 4: Configuration Consolidation
- Merge task definition configurations
- Update environment variables
- Validate deployment scripts reference correct files

## Success Criteria

The cleanup will be considered successful when:
1. All duplicate files are removed
2. All pages use standardized UI components
3. No unused imports or variables remain
4. All functionality continues to work as before
5. Project structure is cleaner and more maintainable
6. Deployment process remains functional