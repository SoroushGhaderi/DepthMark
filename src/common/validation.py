"""Data quality validation utilities."""
from typing import Any, Dict

import pandas as pd


class DataQualityChecker:
    """Validate scraped data quality."""

    @staticmethod
    def check_general_stats(df: pd.DataFrame) -> Dict[str, Any]:
        """
        Validate general stats dataframe.
        Args:
            df: DataFrame containing general match statistics
        Returns:
            Dictionary with validation results
        """
        issues = []
        if df.empty:
            return {
                "passed": False,
                "issues": ["DataFrame is empty"],
                "row_count": 0,
                "null_counts": {},
            }
        required_fields = ["match_id", "home_team_id", "away_team_id"]
        missing_fields = [f for f in required_fields if f not in df.columns]
        if missing_fields:
            issues.append(f"Missing required fields: {missing_fields}")
        for field in required_fields:
            if field in df.columns and df[field].isnull().any():
                null_count = df[field].isnull().sum()
                issues.append(f"Null values found in {field}: {null_count}")
        if "match_id" in df.columns and not pd.api.types.is_integer_dtype(df["match_id"]):
            issues.append("match_id should be integer type")
        if "match_id" in df.columns and df["match_id"].duplicated().any():
            dup_count = df["match_id"].duplicated().sum()
            issues.append(f"Duplicate match_ids found: {dup_count}")
        return {
            "passed": len(issues) == 0,
            "issues": issues,
            "row_count": len(df),
            "null_counts": df.isnull().sum().to_dict(),
        }

    @staticmethod
    def check_player_stats(df: pd.DataFrame) -> Dict[str, Any]:
        """
        Validate player stats.
        Args:
            df: DataFrame containing player statistics
        Returns:
            Dictionary with validation results
        """
        issues = []
        if df.empty:
            return {"passed": True, "issues": [], "row_count": 0}
        if "fotmob_rating" in df.columns:
            invalid_ratings = df[
                (df["fotmob_rating"].notna())
                & ((df["fotmob_rating"] < 0) | (df["fotmob_rating"] > 10))
            ]
            if len(invalid_ratings) > 0:
                issues.append(f"Found {len(invalid_ratings)} invalid ratings (should be 0-10)")
        xg_fields = ["expected_goals", "expected_assists", "xg_plus_xa"]
        for field in xg_fields:
            if field in df.columns:
                invalid_xg = df[(df[field].notna()) & (df[field] < 0)]
                if len(invalid_xg) > 0:
                    issues.append(f"Negative values found in {field}: {len(invalid_xg)} rows")
        if "minutes_played" in df.columns:
            invalid_minutes = df[
                (df["minutes_played"].notna())
                & ((df["minutes_played"] < 0) | (df["minutes_played"] > 150))
            ]
            if len(invalid_minutes) > 0:
                issues.append(f"Invalid minutes_played values: {len(invalid_minutes)} rows")
        if "pass_accuracy" in df.columns:
            invalid_accuracy = df[
                (df["pass_accuracy"].notna())
                & ((df["pass_accuracy"] < 0) | (df["pass_accuracy"] > 100))
            ]
            if len(invalid_accuracy) > 0:
                issues.append(
                    f"Invalid pass_accuracy (should be 0-100): {len(invalid_accuracy)} rows"
                )
        return {"passed": len(issues) == 0, "issues": issues, "row_count": len(df)}

    @staticmethod
    def check_goal_events(df: pd.DataFrame) -> Dict[str, Any]:
        """
        Validate goal events.
        Args:
            df: DataFrame containing goal events
        Returns:
            Dictionary with validation results
        """
        issues = []
        if df.empty:
            return {"passed": True, "issues": [], "row_count": 0}
        required_fields = ["event_id", "goal_time", "home_score", "away_score"]
        missing_fields = [f for f in required_fields if f not in df.columns]
        if missing_fields:
            issues.append(f"Missing required fields: {missing_fields}")
        if "goal_time" in df.columns:
            invalid_time = df[
                (df["goal_time"].notna()) & ((df["goal_time"] < 0) | (df["goal_time"] > 150))
            ]
            if len(invalid_time) > 0:
                issues.append(f"Invalid goal_time values: {len(invalid_time)} rows")
        for field in ["home_score", "away_score"]:
            if field in df.columns:
                invalid_score = df[(df[field].notna()) & (df[field] < 0)]
                if len(invalid_score) > 0:
                    issues.append(f"Negative scores in {field}: {len(invalid_score)} rows")
        return {"passed": len(issues) == 0, "issues": issues, "row_count": len(df)}

    @staticmethod
    def check_shot_events(df: pd.DataFrame) -> Dict[str, Any]:
        """
        Validate shot events.
        Args:
            df: DataFrame containing shot events
        Returns:
            Dictionary with validation results
        """
        issues = []
        if df.empty:
            return {"passed": True, "issues": [], "row_count": 0}
        if "expected_goals" in df.columns:
            invalid_xg = df[
                (df["expected_goals"].notna())
                & ((df["expected_goals"] < 0) | (df["expected_goals"] > 1))
            ]
            if len(invalid_xg) > 0:
                issues.append(f"Invalid xG values (should be 0-1): {len(invalid_xg)} rows")
        coord_fields = ["x", "y", "blocked_x", "blocked_y"]
        for field in coord_fields:
            if field in df.columns:
                invalid_coords = df[(df[field].notna()) & ((df[field] < 0) | (df[field] > 100))]
                if len(invalid_coords) > 0:
                    issues.append(f"Invalid {field} coordinates: {len(invalid_coords)} rows")
        return {"passed": len(issues) == 0, "issues": issues, "row_count": len(df)}

    @staticmethod
    def validate_all_dataframes(dataframes: Dict[str, pd.DataFrame]) -> Dict[str, Dict[str, Any]]:
        """
        Validate all dataframes in the collection.
        Args:
            dataframes: Dictionary of dataframes to validate
        Returns:
            Dictionary mapping dataframe names to validation results
        """
        results = {}
        validation_map = {
            "general_stats": DataQualityChecker.check_general_stats,
            "player_stats": DataQualityChecker.check_player_stats,
            "goal_events": DataQualityChecker.check_goal_events,
            "goals": DataQualityChecker.check_goal_events,
            "shotmap_data": DataQualityChecker.check_shot_events,
            "general": DataQualityChecker.check_general_stats,
            "player": DataQualityChecker.check_player_stats,
            "goal": DataQualityChecker.check_goal_events,
            "shotmap": DataQualityChecker.check_shot_events,
        }
        for df_name, df in dataframes.items():
            if not isinstance(df, pd.DataFrame):
                continue
            validator = validation_map.get(df_name, DataQualityChecker._basic_check)
            results[df_name] = validator(df)
        return results

    @staticmethod
    def _basic_check(df: pd.DataFrame) -> Dict[str, Any]:
        """Basic validation for any dataframe."""
        issues = []
        if df.empty:
            issues.append("DataFrame is empty")
        null_cols = df.columns[df.isnull().all()].tolist()
        if null_cols:
            issues.append(f"Columns with all nulls: {null_cols}")
        return {
            "passed": len(issues) == 0,
            "issues": issues,
            "row_count": len(df),
            "null_percentage": (df.isnull().sum().sum() / (len(df) * len(df.columns)) * 100)
            if not df.empty
            else 0,
        }
