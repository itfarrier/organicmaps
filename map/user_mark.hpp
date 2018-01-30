#pragma once

#include "drape_frontend/user_marks_provider.hpp"

#include "indexer/feature_decl.hpp"

#include "geometry/latlon.hpp"
#include "geometry/point2d.hpp"

#include "base/macros.hpp"

#include "std/string.hpp"
#include "std/unique_ptr.hpp"
#include "std/utility.hpp"

class UserMarkManager;

class UserMark : public df::UserPointMark
{
public:
  enum class Priority: uint16_t
  {
    Default = 0,
    RouteStart,
    RouteFinish,
    RouteIntermediateC,
    RouteIntermediateB,
    RouteIntermediateA,
    TransitStop,
    TransitGate,
    TransitTransfer,
    TransitKeyStop
  };

  enum class Type
  {
    API,
    SEARCH,
    STATIC,
    BOOKMARK,
    ROUTING,
    TRANSIT,
    LOCAL_ADS,
    DEBUG_MARK
  };

  UserMark(m2::PointD const & ptOrg, UserMarkManager * container, Type type, size_t index);

  // df::UserPointMark overrides.
  bool IsDirty() const override { return m_isDirty; }
  void AcceptChanges() const override { m_isDirty = false; }
  bool IsVisible() const override { return true; }
  m2::PointD const & GetPivot() const override;
  m2::PointD GetPixelOffset() const override;
  dp::Anchor GetAnchor() const override;
  float GetDepth() const override;
  df::RenderState::DepthLayer GetDepthLayer() const override;
  drape_ptr<TitlesInfo> GetTitleDecl() const override { return nullptr; }
  drape_ptr<ColoredSymbolZoomInfo> GetColoredSymbols() const override { return nullptr; }
  drape_ptr<SymbolSizes> GetSymbolSizes() const override { return nullptr; }
  drape_ptr<SymbolOffsets> GetSymbolOffsets() const override { return nullptr; }
  uint16_t GetPriority() const override { return static_cast<uint16_t >(Priority::Default); }
  uint32_t GetIndex() const override { return 0; }
  bool HasSymbolPriority() const override { return false; }
  bool HasTitlePriority() const override { return false; }
  int GetMinZoom() const override { return 1; }
  int GetMinTitleZoom() const override { return GetMinZoom(); }
  FeatureID GetFeatureID() const override { return FeatureID(); }
  bool HasCreationAnimation() const override { return false; }

  ms::LatLon GetLatLon() const;
  virtual Type GetMarkType() const { return m_type; };
  virtual bool IsAvailableForSearch() const { return true; }
  size_t GetCategoryIndex() const { return m_index; }

protected:
  void SetDirty() { m_isDirty = true; }

  m2::PointD m_ptOrg;
  mutable UserMarkManager * m_manager;
  Type m_type;
  size_t m_index;

private:
  mutable bool m_isDirty = true;

  DISALLOW_COPY_AND_MOVE(UserMark);
};

class StaticMarkPoint : public UserMark
{
public:
  explicit StaticMarkPoint(UserMarkManager * manager);

  drape_ptr<SymbolNameZoomInfo> GetSymbolNames() const override { return nullptr; }

  void SetPtOrg(m2::PointD const & ptOrg);
};

class MyPositionMarkPoint : public StaticMarkPoint
{
public:
  explicit MyPositionMarkPoint(UserMarkManager * manager);

  void SetUserPosition(m2::PointD const & pt, bool hasPosition)
  {
    SetPtOrg(pt);
    m_hasPosition = hasPosition;
  }
  bool HasPosition() const { return m_hasPosition; }

private:
  bool m_hasPosition = false;
};

class DebugMarkPoint : public UserMark
{
public:
  DebugMarkPoint(m2::PointD const & ptOrg, UserMarkManager * manager);

  drape_ptr<SymbolNameZoomInfo> GetSymbolNames() const override;
};

string DebugPrint(UserMark::Type type);
