"""
FotMob API Response Validator.

Provides validation utilities for FotMob API responses with safe field extraction
and comprehensive error reporting.
"""

from typing import Any, Dict, Optional, List, Tuple
from pathlib import Path
import json
from datetime import datetime

from src.common.logging import get_logger


class SafeFieldExtractor:
    """Helper class for safe field extraction from FotMob API responses."""
    
    @staticmethod
    def safe_get(data: Dict, path: str, default: Any = None) -> Any:
        """
        Safely extract nested field from dictionary using dot notation.
        
        Args:
            data: Source dictionary
            path: Dot-separated path (e.g., 'general.matchId')
            default: Default value if path not found
        
        Returns:
            Value at path or default
        
        Example:
            >>> extractor = SafeFieldExtractor()
            >>> match_id = extractor.safe_get(data, 'general.matchId', default=0)
        """
        keys = path.split('.')
        current = data
        
        for key in keys:
            if isinstance(current, dict):
                current = current.get(key)
                if current is None:
                    return default
            elif isinstance(current, list) and key.isdigit():
                idx = int(key)
                current = current[idx] if idx < len(current) else None
                if current is None:
                    return default
            else:
                return default
        
        return current if current is not None else default
    
    @staticmethod
    def safe_get_nested(data: Dict, *keys, default: Any = None) -> Any:
        """
        Safely extract nested field using multiple keys.
        
        Args:
            data: Source dictionary
            *keys: Variable number of keys to traverse
            default: Default value if path not found
        
        Returns:
            Value at nested path or default
        
        Example:
            >>> home_team = SafeFieldExtractor.safe_get_nested(
            ...     data, 'general', 'homeTeam', 'id', default=0
            ... )
        """
        current = data
        for key in keys:
            if isinstance(current, dict):
                current = current.get(key)
                if current is None:
                    return default
            else:
                return default
        return current if current is not None else default


class FotMobValidator:
    """Validates FotMob API responses for required fields and data quality."""
    
    # Required fields that must be present
    REQUIRED_FIELDS = {
        'general.matchId': (int, str),  # Accept both int and str
        'general.homeTeam.id': int,
        'general.homeTeam.name': str,
        'general.awayTeam.id': int,
        'general.awayTeam.name': str,
        'header.status.finished': bool,
        'header.status.started': bool,
    }
    
    # Fields that should be present if match is finished
    FINISHED_MATCH_FIELDS = {
        'header.status.scoreStr': str,
        'header.teams': list,
    }
    
    # Optional but commonly expected fields
    OPTIONAL_FIELDS = {
        'content.shotmap': (dict, type(None)),
        'content.lineup': (dict, type(None)),
        'content.playerStats': (dict, type(None)),
        'content.matchFacts': (dict, type(None)),
        'content.stats': (dict, type(None)),
    }
    
    def __init__(self):
        """Initialize validator with logger."""
        self.logger = get_logger()
        self.extractor = SafeFieldExtractor()
    
    def validate_response(
        self, 
        data: Dict[str, Any],
        strict: bool = False
    ) -> Tuple[bool, List[str], List[str]]:
        """
        Validate API response has required fields.
        
        Args:
            data: API response data to validate
            strict: If True, also validate optional fields
        
        Returns:
            Tuple of (is_valid, errors, warnings)
        """
        errors = []
        warnings = []
        
        # Validate required fields
        for field_path, expected_types in self.REQUIRED_FIELDS.items():
            value = self.extractor.safe_get(data, field_path)
            
            # Handle tuple of types (accept any of them)
            if isinstance(expected_types, tuple):
                types_list = expected_types
            else:
                types_list = (expected_types,)
            
            if value is None:
                errors.append(f"Missing required field: {field_path}")
            elif not isinstance(value, types_list):
                type_names = ' or '.join(t.__name__ for t in types_list)
                errors.append(
                    f"Invalid type for {field_path}: "
                    f"expected {type_names}, got {type(value).__name__}"
                )
        
        # Check if match is finished
        is_finished = self.extractor.safe_get(data, 'header.status.finished', default=False)
        
        # Validate finished match fields
        if is_finished:
            for field_path, expected_type in self.FINISHED_MATCH_FIELDS.items():
                value = self.extractor.safe_get(data, field_path)
                
                if value is None:
                    warnings.append(
                        f"Missing expected field for finished match: {field_path}"
                    )
                elif not isinstance(value, expected_type):
                    warnings.append(
                        f"Invalid type for finished match field {field_path}: "
                        f"expected {expected_type.__name__}, got {type(value).__name__}"
                    )
        
        # Validate optional fields if strict mode
        if strict:
            for field_path, expected_types in self.OPTIONAL_FIELDS.items():
                value = self.extractor.safe_get(data, field_path)
                
                # Handle tuple of types
                if isinstance(expected_types, tuple):
                    types_list = expected_types
                else:
                    types_list = (expected_types,)
                
                if value is not None and not isinstance(value, types_list):
                    type_names = ' or '.join(t.__name__ for t in types_list if t is not type(None))
                    warnings.append(
                        f"Unexpected type for {field_path}: "
                        f"expected {type_names}, got {type(value).__name__}"
                    )
        
        is_valid = len(errors) == 0
        return is_valid, errors, warnings
    
    def validate_and_report(
        self, 
        data: Dict[str, Any],
        match_id: Optional[str] = None,
        strict: bool = False
    ) -> bool:
        """
        Validate and log detailed report.
        
        Args:
            data: API response data
            match_id: Match ID for logging context
            strict: If True, also validate optional fields
        
        Returns:
            True if validation passed, False otherwise
        """
        is_valid, errors, warnings = self.validate_response(data, strict=strict)
        
        context = f"match {match_id}" if match_id else "response"
        
        if is_valid:
            self.logger.debug(f"[OK] Validation passed for {context}")
            if warnings:
                self.logger.warning(
                    f"Validation warnings for {context} ({len(warnings)}):"
                )
                for warning in warnings:
                    self.logger.warning(f"  - {warning}")
        else:
            self.logger.error(
                f"[ERROR] Validation failed for {context} with {len(errors)} errors:"
            )
            for error in errors:
                self.logger.error(f"  - {error}")
            
            if warnings:
                self.logger.warning(f"Additional warnings ({len(warnings)}):")
                for warning in warnings:
                    self.logger.warning(f"  - {warning}")
        
        return is_valid
    
    def get_validation_summary(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Get detailed validation summary.
        
        Args:
            data: API response data
        
        Returns:
            Dictionary with validation summary
        """
        is_valid, errors, warnings = self.validate_response(data, strict=True)
        
        # Extract key metadata
        match_id = self.extractor.safe_get(data, 'general.matchId')
        home_team = self.extractor.safe_get(data, 'general.homeTeam.name', default='Unknown')
        away_team = self.extractor.safe_get(data, 'general.awayTeam.name', default='Unknown')
        is_finished = self.extractor.safe_get(data, 'header.status.finished', default=False)
        
        # Check data completeness
        has_shotmap = self.extractor.safe_get(data, 'content.shotmap') is not None
        has_lineup = self.extractor.safe_get(data, 'content.lineup') is not None
        has_player_stats = self.extractor.safe_get(data, 'content.playerStats') is not None
        has_momentum = self.extractor.safe_get(data, 'content.momentum') is not None
        
        return {
            'is_valid': is_valid,
            'match_id': match_id,
            'home_team': home_team,
            'away_team': away_team,
            'is_finished': is_finished,
            'error_count': len(errors),
            'warning_count': len(warnings),
            'errors': errors,
            'warnings': warnings,
            'data_completeness': {
                'has_shotmap': has_shotmap,
                'has_lineup': has_lineup,
                'has_player_stats': has_player_stats,
                'has_momentum': has_momentum,
            },
            'validated_at': datetime.now().isoformat()
        }


class ResponseSaver:
    """Save validated API responses to JSON files."""
    
    def __init__(self, output_dir: str = "data/validated_responses"):
        """
        Initialize response saver.
        
        Args:
            output_dir: Directory to save validated responses
        """
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.logger = get_logger()
    
    def save_response(
        self,
        data: Dict[str, Any],
        match_id: str,
        validation_summary: Optional[Dict[str, Any]] = None,
        source: str = "fotmob"
    ) -> Path:
        """
        Save validated response to JSON file.
        
        Args:
            data: Response data to save
            match_id: Match ID
            validation_summary: Optional validation summary to include
            source: Data source name (e.g., 'fotmob')
        
        Returns:
            Path to saved file
        """
        # Create dated subdirectory
        date_str = datetime.now().strftime('%Y%m%d')
        date_dir = self.output_dir / source / date_str
        date_dir.mkdir(parents=True, exist_ok=True)
        
        # Prepare output data
        output_data = {
            'match_id': match_id,
            'source': source,
            'saved_at': datetime.now().isoformat(),
            'data': data
        }
        
        # Add validation summary if provided
        if validation_summary:
            output_data['validation'] = validation_summary
        
        # Save to file
        output_file = date_dir / f"match_{match_id}.json"
        
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(output_data, f, indent=2, ensure_ascii=False)
            
            self.logger.debug(f"Saved validated response for match {match_id} to {output_file}")
            return output_file
            
        except Exception as e:
            self.logger.error(f"Failed to save response for match {match_id}: {e}")
            raise
    
    def save_invalid_response(
        self,
        data: Dict[str, Any],
        match_id: str,
        validation_summary: Dict[str, Any],
        source: str = "fotmob"
    ) -> Path:
        """
        Save invalid response to separate directory for debugging.
        
        Args:
            data: Response data
            match_id: Match ID
            validation_summary: Validation summary with errors
            source: Data source name
        
        Returns:
            Path to saved file
        """
        # Create invalid responses directory
        invalid_dir = self.output_dir / "invalid" / source
        invalid_dir.mkdir(parents=True, exist_ok=True)
        
        # Prepare output data
        output_data = {
            'match_id': match_id,
            'source': source,
            'saved_at': datetime.now().isoformat(),
            'validation_failed': True,
            'validation': validation_summary,
            'data': data
        }
        
        # Save to file
        output_file = invalid_dir / f"match_{match_id}_invalid.json"
        
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(output_data, f, indent=2, ensure_ascii=False)
            
            self.logger.warning(
                f"Saved INVALID response for match {match_id} to {output_file}"
            )
            return output_file
            
        except Exception as e:
            self.logger.error(
                f"Failed to save invalid response for match {match_id}: {e}"
            )
            raise


# Convenience functions
def validate_fotmob_response(
    data: Dict[str, Any],
    match_id: Optional[str] = None,
    strict: bool = False
) -> Tuple[bool, List[str], List[str]]:
    """
    Validate FotMob API response.
    
    Args:
        data: API response data
        match_id: Match ID for logging
        strict: If True, validate optional fields
    
    Returns:
        Tuple of (is_valid, errors, warnings)
    """
    validator = FotMobValidator()
    return validator.validate_response(data, strict=strict)


def save_validated_response(
    data: Dict[str, Any],
    match_id: str,
    output_dir: str = "data/validated_responses",
    source: str = "fotmob",
    validate: bool = True
) -> Tuple[Optional[Path], bool, Optional[Dict[str, Any]]]:
    """
    Validate and save only invalid API responses.
    
    Args:
        data: API response data
        match_id: Match ID
        output_dir: Directory to save invalid responses
        source: Data source name
        validate: If True, validate before saving
    
    Returns:
        Tuple of (file_path, is_valid, validation_summary).
        file_path is None when the response is valid and therefore skipped.
    """
    validator = FotMobValidator()
    saver = ResponseSaver(output_dir)
    
    # Validate if requested
    validation_summary = None
    is_valid = True
    
    if validate:
        validation_summary = validator.get_validation_summary(data)
        is_valid = validation_summary['is_valid']
    
    # Save only invalid responses for debugging
    file_path = None
    if not is_valid:
        file_path = saver.save_invalid_response(data, match_id, validation_summary, source)

    return file_path, is_valid, validation_summary
