#include "AboutForm.hpp"
#include "SceneRegister.hpp"
#include "MapsWithMeForm.hpp"
#include "AppResourceId.h"
#include "../../../base/logging.hpp"
#include "../../../platform/settings.hpp"
#include "../../../platform/tizen_string_utils.hpp"
#include <FWeb.h>
#include <FAppApp.h>
#include <FApp.h>

using namespace Tizen::Base;
using namespace Tizen::Ui;
using namespace Tizen::Ui::Controls;
using namespace Tizen::Ui::Scenes;
using namespace Tizen::App;
using namespace Tizen::Web::Controls;

AboutForm::AboutForm()
{
}

AboutForm::~AboutForm(void)
{
}

bool AboutForm::Initialize(void)
{
  Construct(IDF_ABOUT_FORM);
  return true;
}

result AboutForm::OnInitializing(void)
{
  Label * pCurrentVersionLabel = static_cast<Label*>(GetControl(IDC_VERSION_LABEL, true));

  //  version
  AppResource* pApp = App::GetInstance()->GetAppResource();
  String strVersionFormatter;
  pApp->GetString(IDS_VERSION, strVersionFormatter);
  String const strVersion = App::GetInstance()->GetAppVersion();
  char buff[100];
  sprintf(buff, FromTizenString(strVersionFormatter).c_str(), FromTizenString(strVersion).c_str());
  pCurrentVersionLabel->SetText(buff);

  //  web page
  Web * pWeb = static_cast<Web *>(GetControl(IDC_WEB, true));
  Tizen::Base::String url = "file://";
  url += (Tizen::App::App::GetInstance()->GetAppDataPath());
  url += "about.html";
  pWeb->LoadUrl(url);

  Button * pButtonBack = static_cast<Button *>(GetControl(IDC_CLOSE_BUTTON, true));
  pButtonBack->SetActionId(ID_CLOSE);
  pButtonBack->AddActionEventListener(*this);

  SetFormBackEventListener(this);
  return E_SUCCESS;
}

void AboutForm::OnActionPerformed(const Tizen::Ui::Control & source, int actionId)
{
  switch(actionId)
  {
    case ID_CLOSE:
    {
      SceneManager* pSceneManager = SceneManager::GetInstance();
      pSceneManager->GoBackward(BackwardSceneTransition(SCENE_TRANSITION_ANIMATION_TYPE_RIGHT));
      break;
    }
  }
  Invalidate(true);
}

void AboutForm::OnFormBackRequested(Tizen::Ui::Controls::Form & source)
{
  SceneManager * pSceneManager = SceneManager::GetInstance();
  pSceneManager->GoBackward(BackwardSceneTransition(SCENE_TRANSITION_ANIMATION_TYPE_RIGHT));
}
